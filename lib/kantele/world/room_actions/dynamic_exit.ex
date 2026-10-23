defmodule Kantele.World.RoomActions.DynamicExit do
  @moduledoc """
  运行期动态出口的共享原语（P5-4ae）。

  LPC 里 `set("exits/<dir>", target)` / `delete("exits/<dir>")` 遍地都是（291 个
  调用点、81 个文件），其中约 150 个在玩家可触发的 `do_*` 里 —— 也就是「推石门
  露出密道」「开门」「砸墙」「敲墙」这一整类一次性场景。它们共享同一个形状：

      if (! query("exits/" + dir)) {
              set("exits/" + dir, target);
              message_vision("...开了...");
              remove_call_out("close_x");
              call_out("close_x", N);          // 可选：N 秒后自己合上
      } else
              notify_fail("...已经开了...");

  本模块把这四件事（判在 / 开 / 关 / 定时关）收在一处，房间 handler 只留
  「参数校验 + 条件门控 + 文案」。底层用的是已有的运行时原语
  （`Room.has_exit_by_id?/2` / `Room.set_exit/3` / `Room.delete_exit/2`，
  `room.ex` 的「运行时动态出口增删」段）：直接改房间进程的 `state.data.exits`，
  所以 `look` 与移动**立即**生效，不需要重载房间。

  ## 为什么定时关闭要放这里

  LPC 的 `call_out("close_men", 10)` 有两件事不能省：

  1. **回调拿不到 `conn`** —— 10 秒后玩家可能已经下线/换房间。所以回调只能走
     按 room_id 的运行时原语（`delete_exit` + `Room.tell_room/2`），不能碰 conn。
  2. **必须能取消** —— 否则「开门 → 9 秒后又开一次 → 旧定时器在 10 秒把门关上」
     会把玩家刚开的门关掉。LPC 用 `remove_call_out` 解决；这里把
     `:timer.apply_after/4` 返回的 ref 存进房间 state（`exit_timer:<key>`），
     重开时先 `:timer.cancel/1`。

  `:timer.apply_after/4` 在**独立进程**里回调，因此 `do_close_after/1` 只用
  room_id 级原语；房间进程已销毁时 `delete_exit` 返回 `:error`、
  `tell_room` 广播给空列表 —— 都安全降级。

  ## 与 LPC 的差异

  - LPC 的 `find_object/load_object` + `objectp(room)` 判空：本引擎的房间进程
    恒在监督树下（`Room.ensure_started/1` 语义），`set_exit/delete_exit` 对不存在
    的房间返回 `:error`，等价于 LPC `objectp(room) == 0` 的静默跳过。
  - LPC 允许 `set("exits/x", __FILE__)` 指向自身所在文件；这里由调用方直接传
    目标 room id（`__FILE__` 就是当前房间 id），语义一致。
  """
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @doc "`query(\"exits/<dir>\")` 等价：房间当前是否有该方向的出口。"
  def open?(room_id, dir) when is_binary(room_id) and is_binary(dir),
    do: Room.has_exit_by_id?(room_id, dir)

  def open?(_room_id, _dir), do: false

  @doc """
  `set("exits/<dir>", target)` + `message_vision(vision, me)`。

  `vision` 里可以写 `$N`（由 `broadcast_vision/4` 归一化为 `{npc}`，行动者看到
  「你」、旁观者看到名字）。返回更新后的 `conn`。
  """
  def open(conn, room_id, dir, target, vision)
      when is_binary(room_id) and is_binary(dir) and is_binary(target) do
    Room.set_exit(room_id, dir, target)
    broadcast(conn, room_id, vision)
  end

  @doc "`delete(\"exits/<dir>\")` + `message_vision(vision, me)`。"
  def close(conn, room_id, dir, vision) when is_binary(room_id) and is_binary(dir) do
    Room.delete_exit(room_id, dir)
    broadcast(conn, room_id, vision)
  end

  @doc """
  「没开就开、已开就关」的双态切换（`baituo:neishi` 的花盆那种）。

  `open_vision` 在开的时候播、`close_vision` 在关的时候播。
  """
  def toggle(conn, room_id, dir, target, open_vision, close_vision)
      when is_binary(room_id) and is_binary(dir) do
    if open?(room_id, dir) do
      close(conn, room_id, dir, close_vision)
    else
      open(conn, room_id, dir, target, open_vision)
    end
  end

  # ---- 定时关闭（LPC `call_out` + `remove_call_out`） ----

  @doc """
  `remove_call_out(key); call_out(key, ms/1000)` 等价：`ms` 毫秒后关闭出口。

  `targets` 是 `{room_id, dir, message}` 三元组列表 —— 双向门要同时关两边
  （`xunbufang`/`laofang`、`jingxiu`/`xiuxishi` 都是这样），所以天生支持多目标。
  `message` 为 `nil` 时静默关闭。

  `owner_room_id` + `timer_key` 用来登记 timer ref 以便取消；同一个
  `owner_room_id` 下同一个 `timer_key` 只会有一个有效定时器。

  选项：

  - `:only_if_open`（默认 `false`）—— 为 `true` 时**只有出口仍然存在**才关闭并
    播报，等价 LPC 回调首行的 `if (! query("exits/<dir>")) return;`
    （`meizhuang:didao3 close_path`、`huashan:xiuxishi close_men` 都有这个守卫）。
    默认 `false` 对应没有守卫的回调（`guanwai:xiuxishi close_men`、
    `lingxiao:shanya close`）—— 它们即使出口已被手动关掉，也会再播一次
    「自己合上了」。
  """
  def close_after(ms, owner_room_id, timer_key, targets, opts \\ [])
      when is_integer(ms) and ms > 0 and is_binary(owner_room_id) do
    cancel_close(owner_room_id, timer_key)

    args = [normalize_targets(targets), Keyword.get(opts, :only_if_open, false)]

    # 注意 `:timer.apply_after/4` 返回的是 `{:ok, {:once, ref}}` —— TRef 是**元组**
    # 不是裸 `reference()`。所以这里原样存 TRef，`cancel_close/2` 也不再拿
    # `is_reference/1` 当守卫（那样取消会变成空操作，本批单测抓到过这个坑）。
    case :timer.apply_after(ms, __MODULE__, :do_close_after, args) do
      {:ok, tref} ->
        Room.put_state_by_id(owner_room_id, timer_key, tref)
        :ok

      _other ->
        :ok
    end
  end

  @doc """
  `remove_call_out(key)` 等价：取消该房间上尚未触发的定时关闭。

  没有待取消的定时器时静默返回 `:ok`（LPC 同样不报错）。
  """
  def cancel_close(owner_room_id, timer_key) when is_binary(owner_room_id) do
    case Room.get_state_by_id(owner_room_id, timer_key) do
      nil ->
        :ok

      tref ->
        # TRef 由 `:timer.apply_after/4` 产出（形如 `{:once, ref}`），直接交给
        # `:timer.cancel/1`；这里不做形状校验，见 `close_after/5` 的注释。
        :timer.cancel(tref)
        Room.delete_state_by_id(owner_room_id, timer_key)
        :ok
    end
  end

  def cancel_close(_owner_room_id, _timer_key), do: :ok

  @doc """
  定时器回调：关闭 `targets` 里的所有出口，并按需向各房间播报。

  由 `:timer.apply_after/4` 在独立进程调用，**没有 `conn`**，所以走
  `Room.delete_exit/2` + `Room.tell_room/2`（`{:room_message, _}` 由角色进程的
  Foreman 渲染）。重复触发是幂等的：出口本来就没有时 `delete_exit` 无副作用。

  `only_if_open` 为 `true` 时先判出口是否存在，不存在就跳过（连文案一起跳过）。
  """
  def do_close_after(targets, only_if_open \\ false) do
    Enum.each(normalize_targets(targets), fn {room_id, dir, message} ->
      cond do
        only_if_open and not open?(room_id, dir) ->
          :ok

        true ->
          Room.delete_exit(room_id, dir)

          if is_binary(message) and message != "",
            do: Room.tell_room(%Room{id: room_id}, message)
      end
    end)

    :ok
  end

  # 允许调用方写 `{room_id, dir}` 二元组（不播报），统一补成三元组；形状不对的
  # 条目直接丢掉（定时器在独立进程里跑，崩了没人接）。
  defp normalize_targets(targets) do
    targets
    |> List.wrap()
    |> Enum.flat_map(fn
      {room_id, dir, message} when is_binary(room_id) and is_binary(dir) ->
        [{room_id, dir, message}]

      {room_id, dir} when is_binary(room_id) and is_binary(dir) ->
        [{room_id, dir, nil}]

      _other ->
        []
    end)
  end

  defp broadcast(conn, room_id, vision) when is_binary(vision) and vision != "",
    do: Helpers.broadcast_vision(conn, room_id, vision)

  defp broadcast(conn, _room_id, _vision), do: conn
end

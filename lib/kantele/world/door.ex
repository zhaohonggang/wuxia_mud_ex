defmodule Kantele.World.Door do
  @moduledoc """
  门/容器统一框架（P5-6）。

  把散在各房的 `do_open/do_close/do_knock` 重复逻辑收到一处，各房 handler
  只留「参数校验 + 条件门控 + 文案」。底层复用 `DynamicExit` 的运行时原语
  （`Room.set_exit/delete_exit/has_exit_by_id?`），门状态持久化在房间 state
  里（`"door:<dir>"`）。

  典型 LPC 形状：

      if (query("exits/north")) return notify_fail("门已经是开着的。\n");
      set("exits/north", target);
      message_vision("$N把门打开了。\n", this_player());
      room->set("exits/south", __FILE__);
      remove_call_out("close_door");
      call_out("close_door", 10);

  对应框架：

      Door.open(conn, room_id, "north", target, nil,
        neighbor_room: neighbor_id, neighbor_dir: "south", neighbor_vision: n_vision)
      Door.schedule_auto_close(room_id, "exit_timer:door", 10_000,
        [{room_id, "north", nil}, {neighbor_id, "south", nil}])

  ## 与 DynamicExit 的关系

  `DynamicExit` 提供裸出口增删 + 定时器（`open/close/close_after/cancel_close`）。
  本模块在其上层加上「门状态持久化 + 双向出口同步 + 锁定状态 + valid_leave 门控」，
  各房门 handler 再薄封装即可，不再重复造轮子。

  ## 注意

  所有可选参数均放在 `opts` 关键字列表里，**不要**给 `vision`/`opts` 声明
  `\\` 默认值，否则关键字列表会绑定到 `vision` 而非 `opts`（Elixir 默认参数陷阱）。
  需要无视觉文案时传 `nil` 作为 `vision`。
  """

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit

  defstruct [:open?, :locked?, :auto_close_ms, :timer_key]

  defp default_state,
    do: %__MODULE__{open?: false, locked?: false, auto_close_ms: nil, timer_key: nil}

  @doc "门状态在 `room.state` 里的键：`\"door:<dir>\"`"
  def state_key(dir), do: "door:" <> dir

  @doc "读取指定方向的门状态（不存在则返回缺省）。"
  def state(room_id, dir) when is_binary(room_id) and is_binary(dir) do
    case Room.get_state_by_id(room_id, state_key(dir)) do
      %__MODULE__{} = state -> state
      _other -> default_state()
    end
  end

  def state(_room_id, _dir), do: default_state()

  @doc """
  指定方向的门当前是否已开（等价 LPC `query("exits/<dir>")`）。

  以出口是否存在为准，与 `DynamicExit.open?/2` 一致。
  """
  def open?(room_id, dir) when is_binary(room_id) and is_binary(dir),
    do: DynamicExit.open?(room_id, dir)

  def open?(_room_id, _dir), do: false

  @doc "指定方向的门当前是否锁定。"
  def locked?(room_id, dir) when is_binary(room_id) and is_binary(dir),
    do: state(room_id, dir).locked?

  def locked?(_room_id, _dir), do: false

  @doc """
  锁定指定方向的门（写 `room.state["door:<dir>"].locked? = true`）。

  锁定后 `open/6` 拒绝打开，`valid_leave/5` 可据此拦截移动。
  """
  def lock(room_id, dir) when is_binary(room_id) and is_binary(dir) do
    put_state(room_id, dir, &put_in(&1.locked?, true))
    :ok
  end

  def lock(_room_id, _dir), do: :error

  @doc "解锁指定方向的门。"
  def unlock(room_id, dir) when is_binary(room_id) and is_binary(dir) do
    put_state(room_id, dir, &put_in(&1.locked?, false))
    :ok
  end

  def unlock(_room_id, _dir), do: :error

  @doc """
  打开门：设本房出口、同步邻房出口、更新门状态、播报文案、可选登记自动关门。

  `vision` 为本房广播文案（`nil` 则不播）；`opts` 可选：
  - `:neighbor_room` / `:neighbor_dir` — 邻房反向出口（双向门时必传）
  - `:neighbor_vision` — 发给邻房的纯文本（行动者不在邻房，无 VisionView）
  - `:auto_close_ms` — 毫秒后自动关门，配合 `schedule_auto_close/5`
  - `:close_targets` — 自动关门时的目标列表（默认本房出口 + 邻房出口）
  - `:only_if_open` — 自动关门守卫，默认 `true`
  - `:timer_key` — 自动关门定时器键（默认 `"exit_timer:door:<room_id>:<dir>"`）

  返回 `{:ok, conn}` 或 `{:error, :already_open}` / `{:error, :locked}` /
  `{:error, :invalid_args}`。
  """
  def open(conn, room_id, dir, target, vision, opts)
      when is_binary(room_id) and is_binary(dir) and is_binary(target) do
    cond do
      locked?(room_id, dir) ->
        {:error, :locked}

      open?(room_id, dir) ->
        {:error, :already_open}

      true ->
        do_open(conn, room_id, dir, target, vision, opts)
    end
  end

  def open(_conn, _room_id, _dir, _target, _vision, _opts),
    do: {:error, :invalid_args}

  @doc "无 opts 的 open 便利封装。"
  def open(conn, room_id, dir, target, vision),
    do: open(conn, room_id, dir, target, vision, [])

  @doc """
  关闭门：删本房出口、同步删邻房出口、更新门状态、播报文案、取消自动关门。

  `vision` 为本房广播文案（`nil` 则不播）；`opts` 可选：
  - `:neighbor_room` / `:neighbor_dir` — 邻房反向出口（双向门时必传）
  - `:neighbor_vision` — 发给邻房的纯文本
  - `:timer_key` / `:owner_room_id` — 取消自动关门定时器时用

  返回 `{:ok, conn}` 或 `{:error, :already_closed}` /
  `{:error, :invalid_args}`。
  """
  def close(conn, room_id, dir, vision, opts)
      when is_binary(room_id) and is_binary(dir) do
    cond do
      not open?(room_id, dir) ->
        {:error, :already_closed}

      true ->
        do_close(conn, room_id, dir, vision, opts)
    end
  end

  def close(_conn, _room_id, _dir, _vision, _opts),
    do: {:error, :invalid_args}

  @doc "无 opts 的 close 便利封装。"
  def close(conn, room_id, dir, vision),
    do: close(conn, room_id, dir, vision, [])

  @doc """
  登记自动关门定时器：`ms` 毫秒后关闭 `targets` 里的所有出口，并按需播报。

  同一 `owner_room_id` + `timer_key` 只保留一个有效定时器，重登记前先取消旧的
  （等价 LPC `remove_call_out(key)`）。`only_if_open: true` 时只有出口仍存在才关闭。

  返回 `:ok` 或 `{:error, :invalid_args}`。
  """
  def schedule_auto_close(ms, owner_room_id, timer_key, targets, opts)
      when is_integer(ms) and ms > 0 and is_binary(owner_room_id) and is_binary(timer_key) do
    DynamicExit.close_after(ms, owner_room_id, timer_key, targets, opts)
    :ok
  end

  def schedule_auto_close(_ms, _owner_room_id, _timer_key, _targets, _opts),
    do: :error

  @doc "无 opts 的 schedule_auto_close 便利封装。"
  def schedule_auto_close(ms, owner_room_id, timer_key, targets),
    do: schedule_auto_close(ms, owner_room_id, timer_key, targets, [])

  @doc "取消尚未触发的自动关门定时器。返回 `:ok` 或 `{:error, :invalid_args}`。"
  def cancel_auto_close(owner_room_id, timer_key) when is_binary(owner_room_id) do
    DynamicExit.cancel_close(owner_room_id, timer_key)
    :ok
  end

  def cancel_auto_close(_owner_room_id, _timer_key), do: :error

  @doc """
  valid_leave 权限门控：判断玩家能否经 `dir` 方向离开房间。

  `player_id` 为玩家 id（binary）；`allow_list` / `deny_list` 为玩家 id 列表。

  返回 `{:allow, message}` / `{:deny, message}` / `{:passthrough}`。
  - 门不存在或已开 → `:passthrough`（不拦截，交由其他守卫）
  - 门关且锁定，玩家在 `deny_list` → `{:deny, "门锁着，你进不去。\n"}`
  - 门关且锁定，玩家在 `allow_list` → `{:allow, "请进。\n"}`
  - 门关且锁定，玩家都不在 → `{:deny, "门锁着，非请莫入。\n"}`

  `deny_list` 优先级高于 `allow_list`。
  """
  def valid_leave(room_id, dir, player_id, allow_list, deny_list)
      when is_binary(room_id) and is_binary(dir) and is_binary(player_id) and
             is_list(allow_list) and is_list(deny_list) do
    cond do
      not open?(room_id, dir) and not locked?(room_id, dir) ->
        {:passthrough}

      locked?(room_id, dir) and player_id in deny_list ->
        {:deny, "门锁着，你进不去。\n"}

      locked?(room_id, dir) and player_id in allow_list ->
        {:allow, "请进。\n"}

      locked?(room_id, dir) ->
        {:deny, "门锁着，非请莫入。\n"}

      true ->
        {:passthrough}
    end
  end

  def valid_leave(_room_id, _dir, _player_id, _allow_list, _deny_list),
    do: {:passthrough}

  # ---- 便利封装（无 allow/deny 列表时调用） ----

  @doc "无名单的 valid_leave：门锁定时一律 :deny，否则 :passthrough。"
  def valid_leave(room_id, dir, player_id)
      when is_binary(room_id) and is_binary(dir) and is_binary(player_id),
      do: valid_leave(room_id, dir, player_id, [], [])

  # ---- 内部实现 ----

  defp put_state(room_id, dir, updater) do
    current = state(room_id, dir)
    new_state = updater.(current)
    Room.put_state_by_id(room_id, state_key(dir), new_state)
    :ok
  end

  defp do_open(conn, room_id, dir, target, vision, opts) do
    neighbor_room = Keyword.get(opts, :neighbor_room)
    neighbor_dir = Keyword.get(opts, :neighbor_dir)
    neighbor_vision = Keyword.get(opts, :neighbor_vision)
    auto_close_ms = Keyword.get(opts, :auto_close_ms)
    close_targets = Keyword.get(opts, :close_targets)
    only_if_open = Keyword.get(opts, :only_if_open, true)
    timer_key = Keyword.get(opts, :timer_key, "exit_timer:door:#{room_id}:#{dir}")

    # 1. 设本房出口 + 本房广播
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    # 2. 同步邻房反向出口（双向门）
    if is_binary(neighbor_room) and is_binary(neighbor_dir) do
      Room.set_exit(neighbor_room, neighbor_dir, room_id)

      if is_binary(neighbor_vision) and neighbor_vision != "" do
        Room.tell_room(%Room{id: neighbor_room}, neighbor_vision)
      end
    end

    # 3. 更新门状态：已开
    new_state = %__MODULE__{
      open?: true,
      locked?: false,
      auto_close_ms: auto_close_ms,
      timer_key: nil
    }

    Room.put_state_by_id(room_id, state_key(dir), new_state)

    # 4. 登记自动关门
    if is_integer(auto_close_ms) and auto_close_ms > 0 do
      targets =
        close_targets ||
          [{room_id, dir, nil}] ++
            if is_binary(neighbor_room) and is_binary(neighbor_dir),
              do: [{neighbor_room, neighbor_dir, nil}],
              else: []

      DynamicExit.close_after(auto_close_ms, room_id, timer_key, targets,
        only_if_open: only_if_open
      )

      # 把 timer_key 回写进门状态，供后续 cancel_auto_close 使用
      Room.put_state_by_id(room_id, state_key(dir), %__MODULE__{new_state | timer_key: timer_key})
    end

    {:ok, conn}
  end

  defp do_close(conn, room_id, dir, vision, opts) do
    neighbor_room = Keyword.get(opts, :neighbor_room)
    neighbor_dir = Keyword.get(opts, :neighbor_dir)
    neighbor_vision = Keyword.get(opts, :neighbor_vision)
    timer_key = Keyword.get(opts, :timer_key) || state(room_id, dir).timer_key
    owner_room_id = Keyword.get(opts, :owner_room_id, room_id)

    # 1. 取消自动关门定时器
    if is_binary(timer_key) do
      DynamicExit.cancel_close(owner_room_id, timer_key)
    end

    # 2. 删本房出口 + 本房广播
    conn = DynamicExit.close(conn, room_id, dir, vision)

    # 3. 同步删邻房反向出口
    if is_binary(neighbor_room) and is_binary(neighbor_dir) do
      Room.delete_exit(neighbor_room, neighbor_dir)

      if is_binary(neighbor_vision) and neighbor_vision != "" do
        Room.tell_room(%Room{id: neighbor_room}, neighbor_vision)
      end
    end

    # 4. 更新门状态：已关
    Room.put_state_by_id(room_id, state_key(dir), %__MODULE__{
      open?: false,
      locked?: false,
      auto_close_ms: nil,
      timer_key: nil
    })

    {:ok, conn}
  end
end

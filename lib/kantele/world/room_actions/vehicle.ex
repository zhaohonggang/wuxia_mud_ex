defmodule Kantele.World.RoomActions.Vehicle do
  @moduledoc """
  P5-8 / 通信中继·载具：`on_board` 定时载具共享原语。

  LPC 里 heimuya 吊篮（up2→up3→up4，经 `basket` 中转房）与 guiyun 渡船
  （taihu↔matou，经 `duchuan` 中转房）是一组同源的「触发 → 上船 → 到站 → 收船」
  四步定时载具，形状完全统一：

      check_trigger(): 若出口 enter 不存在且载具未触发 →
          设 trigger.enter = vehicle，vehicle.out = trigger（双向出口），
          广播「载具来了」，call_out(on_board, T1)
      on_board():     若 enter 仍存在 → 删 enter + vehicle.out，广播「开船」，call_out(arrive, T2)
      arrive():       设 vehicle.out = dest，广播「到站」，call_out(close_passage, T3)
      close_passage(): 删 vehicle.out，广播「收船」，清载具触发标记

  底层复用运行时原语 `Room.set_exit/3` / `delete_exit/2` / `has_exit_by_id?/2` /
  `tell_room/2` / `put_state_by_id/2` / `get_state_by_id/2` / `delete_state_by_id/2`
  （同 `DynamicExit`），定时器走 `:timer.apply_after/4`（独立进程回调，无 conn，
  只用 room_id 级原语——与 P5-4 的 `trap/effect` 延时通道同源思路）。

  ## 与 LPC 的保真 / 差异
  - LPC 用 `insert_trigger` / `yell_trigger` 房间标记防止「骑乘途中重复触发」本载具。
    这里用中转房的 state 标记 `trigger_flag` 等价实现：check_trigger 仅在标记未置位时
    启动链路并置位，close_passage 时清位。这样 up2 的 ride 进行中（enter 已删但
    vehicle.out 仍在）不会被 up2 的再次 insert 打断。
  - LPC `on_board` 首行 `if (! query("exits/enter")) return;` 守卫保留
    （enter 已被删则跳过整段）。
  - LPC `do_yell` / `do_cross` / `do_shang` / `do_insert` 的 arg 校验（如喊话内容、
    上船对象、插入物）首版未移植——所有触发动词统一走 check_trigger（载具触发语义
    一致）。如需严格 arg 门控，后续在 `Vehicle.Trigger.run/2` 里按 `trailing` 分支。
  - 中转房（basket / duchuan）自身由 zone 既有定义提供，本模块不改其静态 exits。
  """

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @doc """
  `check_trigger` 等价：玩家在某 trigger 房触发载具。

  `cfg` 字段：
  - `vehicle`：中转房 id（basket / duchuan）
  - `enter_dir` / `out_dir`：trigger→vehicle / vehicle→trigger 的双向出口方向
  - `dest`：arrive 时中转房 `out` 指向的目标房（下一程）
  - `timings %{on_board, arrive, close}`：三步定时（毫秒）
  - `trigger_vision` / `vehicle_vision`：check_trigger 时分别广播给 trigger 房 / 中转房
  - `busy_vision`：载具已在途（标记已置）时的「等下拨儿」提示
  - `already_vision`：enter 出口已存在（载具正停靠）时的提示（heimuya 无，guiyun 有）
  - `on_board_vision` / `on_board_vehicle_vision`：开船时分别广播给 trigger 房 / 中转房
  - `arrive_vision` / `close_vision`：到站 / 收船时广播给中转房
  - `trigger_flag`：中转房 state 键（防重触发）
  - `timer_key`：定时器登记键前缀（按 trigger 房区分，避免多程冲突）
  """
  def check_trigger(conn, room_id, cfg) do
    cond do
      Room.has_exit_by_id?(room_id, cfg.enter_dir) ->
        if cfg.already_vision,
          do: Helpers.broadcast_vision(conn, room_id, cfg.already_vision),
          else: conn

      Room.get_state_by_id(cfg.vehicle, cfg.trigger_flag) != nil ->
        if cfg.busy_vision,
          do: Helpers.broadcast_vision(conn, room_id, cfg.busy_vision),
          else: conn

      true ->
        start_chain(conn, room_id, cfg)
    end
  end

  defp start_chain(conn, room_id, cfg) do
    Room.put_state_by_id(cfg.vehicle, cfg.trigger_flag, 1)
    Room.set_exit(room_id, cfg.enter_dir, cfg.vehicle)

    conn =
      if cfg.trigger_vision do
        Helpers.broadcast_vision(conn, room_id, cfg.trigger_vision)
      else
        conn
      end

    Room.set_exit(cfg.vehicle, cfg.out_dir, room_id)
    if cfg.vehicle_vision, do: Room.tell_room(%Room{id: cfg.vehicle}, cfg.vehicle_vision)
    schedule(room_id, cfg, :on_board, cfg.timings.on_board)
    conn
  end

  @doc "定时器回调（独立进程，无 conn）：删 enter + 中转 out，广播开船，排 arrive。"
  def on_board(room_id, cfg) do
    if Room.has_exit_by_id?(room_id, cfg.enter_dir) do
      Room.delete_exit(room_id, cfg.enter_dir)
      Room.delete_exit(cfg.vehicle, cfg.out_dir)
      if cfg.on_board_vision, do: Room.tell_room(%Room{id: room_id}, cfg.on_board_vision)
      if cfg.on_board_vehicle_vision, do: Room.tell_room(%Room{id: cfg.vehicle}, cfg.on_board_vehicle_vision)
      schedule(cfg.vehicle, cfg, :arrive, cfg.timings.arrive)
    end

    :ok
  end

  @doc "定时器回调：设 中转.out = dest，广播到站，排 close_passage。"
  def arrive(_room_id, cfg) do
    Room.set_exit(cfg.vehicle, cfg.out_dir, cfg.dest)
    if cfg.arrive_vision, do: Room.tell_room(%Room{id: cfg.vehicle}, cfg.arrive_vision)
    schedule(cfg.vehicle, cfg, :close_passage, cfg.timings.close)
    :ok
  end

  @doc "定时器回调：删 中转.out，广播收船，清触发标记。"
  def close_passage(_room_id, cfg) do
    Room.delete_exit(cfg.vehicle, cfg.out_dir)
    if cfg.close_vision, do: Room.tell_room(%Room{id: cfg.vehicle}, cfg.close_vision)
    Room.delete_state_by_id(cfg.vehicle, cfg.trigger_flag)
    :ok
  end

  # ---- 定时器（LPC call_out / remove_call_out） ----
  # 把 tref 存进 owner 房 state，重触发时先 cancel 掉旧的（等价 remove_call_out）。
  defp schedule(owner, cfg, step, ms) do
    key = "#{cfg.timer_key}:#{step}"
    cancel(owner, key)

    case :timer.apply_after(ms, __MODULE__, step, [owner, cfg]) do
      {:ok, tref} ->
        Room.put_state_by_id(owner, key, tref)

      _other ->
        :ok
    end
  end

  defp cancel(owner, key) do
    case Room.get_state_by_id(owner, key) do
      nil -> :ok
      tref -> :timer.cancel(tref); Room.delete_state_by_id(owner, key)
    end
  end
end

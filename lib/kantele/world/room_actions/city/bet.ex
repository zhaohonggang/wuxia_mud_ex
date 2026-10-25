defmodule Kantele.World.RoomActions.City.Bet do
  @moduledoc """
  赌场房动作：`bet`（P5-9 #9 一次性场景，移植自 `d/city/bet.c`）。

  与 `pig_room` 同构：本模块只做三件事——取状态、分发、落世界。牌局/骰局逻辑
  全在纯模块 `Kantele.World.Casino`，本模块负责：

  1. **取状态**：房间 `state["casino"]`（`Room.get_state_by_id/2`，仅内存）。
     不存在时用 `Casino.new/0`（对应 LPC `create()` 初始 `room_status = 0`）。
  2. **分发**：`do_bet` 时按 LPC `do_bet` 的语义校验后调 `Casino.place_bet/4`，
     扣玩家的扁平铜钱 `meta.coins`，把下注记进房间状态并广播 vision。
  3. **落世界**：`{:ok, _}` 时写回房间状态；定时序列（`prepare→start→perform×2→
     finish`，对应 LPC 四段 `call_out`）由 `:timer.apply_after` 编排（同
     `RoomActions.Vehicle`），每个阶段调 `Casino.*` 后广播并写回状态。

  ## 庄家在场校验

  LPC `do_bet` 先 `present("zhuang jia", this_object())` 判庄家在场。本移植查
  `Room.npc_characters_by_id/1` 是否有名为「庄家」或 id 含 `zhuangjia` 的 NPC
  （UCL `city:bet` 的 `room_characters` 已挂 `characters.changan_zhuangjia`）。

  ## 赢钱如何到手

  `meta` 只有角色自己的进程能安全修改，因此 `finish_round` 对**赢家**发
  `casino/payout` 事件（见 `Kantele.Character.CasinoPayoutEvent`），由各自角色进程
  加铜钱；行动者下注时扣币在本进程内直接完成。

  ## 与 LPC 的差异

  - 货币：LPC 按 gold/silver/coin 三种通货 + `base_value` 折算上限 10 两黄金；
    本移植是扁平铜钱，押注额直接按铜钱计，货币种类 token 仅作语法占位。
  - 骰子画面：LPC 用 ASCII 骰面图，本移植简化为播报点数（视觉等价，非玩法差异）。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Casino
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  # 定时序列延时（ms），对应 LPC call_out 秒数。
  @prepare_to_start 24_000
  @start_to_perform_0 6_000
  @start_to_perform_1 12_000
  @start_to_finish 18_000
  @finish_to_prepare 5_000

  @impl true
  def run(conn, %{verb: "do_bet", trailing: arg, room_id: room_id}) do
    case Map.get(conn, :character) do
      %{id: id, name: name} when is_binary(id) and is_binary(room_id) ->
        player = %{id: id, name: name}

        if dealer_present?(room_id) do
          handle_bet(conn, room_id, player, String.trim(arg))
        else
          {:handled, Helpers.render_to_player(conn, "庄家都没有，你要和谁赌？\n")}
        end

      _ ->
        :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  # ---- 下注（dealer 已确认在场）----

  defp handle_bet(conn, room_id, player, arg) do
    case String.split(arg) do
      [kind, amount_str, _money] ->
        case Integer.parse(amount_str) do
          {amount, ""} -> place(conn, room_id, player, kind, amount)
          _ -> {:handled, Helpers.render_to_player(conn, bet_usage())}
        end

      _ ->
        {:handled, Helpers.render_to_player(conn, bet_usage())}
    end
  end

  defp place(conn, room_id, player, kind, amount) do
    state = load(room_id) |> ensure_running(room_id)

    case Casino.place_bet(state, player, kind, amount) do
      {:error, msg} ->
        {:handled, Helpers.render_to_player(conn, msg)}

      {:ok, new_state} ->
        case deduct(conn, amount) do
          {:error, msg} ->
            {:handled, Helpers.render_to_player(conn, msg)}

          {:ok, conn2} ->
            Room.put_state_by_id(room_id, "casino", new_state)

            conn2
            |> Helpers.broadcast_vision(room_id,
              "#{player.name}拿出#{amount}文铜钱，押在#{Casino.kind_name(kind)}上。\n")
            |> then(&{:handled, &1})
        end
    end
  end

  # 首注时若房间还未开盘（status 0），立即开盘并启动定时序列。
  defp ensure_running(%{status: 0} = state, room_id) do
    prepare_round(room_id, state)
    load(room_id)
  end

  defp ensure_running(state, _room_id), do: state

  # 扣扁平铜钱；不足返回「你有那么多钱吗」。
  defp deduct(conn, amount) do
    character = current(conn)

    case character.meta.coins do
      coins when is_integer(coins) and coins >= amount ->
        meta = %{character.meta | coins: coins - amount}
        {:ok, put_character(conn, %{character | meta: meta})}

      _ ->
        {:error, "庄家皱眉道：你有那么多钱吗？\n"}
    end
  end

  # ---- 定时序列（公开，便于测试直接驱动；正常由 :timer.apply_after 串起）----

  @doc "开盘：确定头彩骰、广播、置押注窗口、排 start。"
  def prepare_round(room_id, state \\ nil) do
    state = Casino.prepare(state || load(room_id))
    Room.put_state_by_id(room_id, "casino", state)
    broadcast(room_id, "庄家唱道：新开盘！预叫头彩！\n")
    broadcast(room_id, "庄家将两枚玉骰往银盘中一撒。\n")
    broadcast(room_id, "头彩骰号是「#{elem(state.big, 0)}」和「#{elem(state.big, 1)}」。\n")
    broadcast(room_id, "接着庄家麻利地顺手将玉骰收回：现在开盘押钱！\n")
    :timer.apply_after(@prepare_to_start, __MODULE__, :start_round, [room_id])
    :ok
  end

  @doc "封盘：关闭押注窗口、广播、排两次摇骰与结算。"
  def start_round(room_id) do
    state = Casino.start(load(room_id))
    Room.put_state_by_id(room_id, "casino", state)
    broadcast(room_id, "庄家喊声：封盘停押！\n")
    broadcast(room_id, "庄家将两枚玉骰扔进两个金盅，一手持一盅摇将起来。\n")
    :timer.apply_after(@start_to_perform_0, __MODULE__, :perform_die, [room_id, 0])
    :timer.apply_after(@start_to_perform_1, __MODULE__, :perform_die, [room_id, 1])
    :timer.apply_after(@start_to_finish, __MODULE__, :finish_round, [room_id])
    :ok
  end

  @doc "摇出第 i 枚开盅骰并广播。"
  def perform_die(room_id, i) do
    state = Casino.perform(load(room_id), i)
    Room.put_state_by_id(room_id, "casino", state)
    r = Enum.at(state.res, i)
    broadcast(room_id, "金盅倒扣在银盘上，玉骰滚了出来：#{r} 点。\n")
    :ok
  end

  @doc "结算：判赢家、广播、给赢家加币（发 casino/payout 事件）、重开盘。"
  def finish_round(room_id) do
    {state, winner, total, payouts} = Casino.finish(load(room_id))
    Room.put_state_by_id(room_id, "casino", state)

    if total == 0 do
      broadcast(room_id, "庄家叫道：空盘！\n")
    else
      broadcast(room_id, "庄家叫道：#{Casino.kind_name(winner)}！\n")
    end

    Enum.each(payouts, fn p ->
      if p.won and p.payout > 0 do
        send_payout(p.player_id, p.payout)
      end
    end)

    :timer.apply_after(@finish_to_prepare, __MODULE__, :prepare_round, [room_id])
    :ok
  end

  # ---- 状态存取 ----

  defp load(room_id) do
    case Room.get_state_by_id(room_id, "casino") do
      %{status: _} = state -> state
      _ -> Casino.new()
    end
  end

  defp broadcast(room_id, text) do
    Room.tell_room(%Room{id: room_id}, text)
    :ok
  end

  # ---- 庄家在场 ----

  defp dealer_present?(room_id) when is_binary(room_id) do
    Enum.any?(Room.npc_characters_by_id(room_id), fn c ->
      c.name == "庄家" or String.contains?(to_string(c.id), "zhuangjia")
    end)
  end

  defp dealer_present?(_room_id), do: false

  # ---- 加币（跨进程，同 pig_room 的 pig/seat）----

  defp send_payout(player_id, amount) when is_binary(player_id) and is_integer(amount) do
    for {_channel, pid, _opts} <- Kantele.Communication.subscribers("characters:#{player_id}") do
      if is_pid(pid) do
        send(pid, %Kalevala.Event{
          from_pid: self(),
          topic: "casino/payout",
          data: %{amount: amount}
        })
      end
    end

    :ok
  end

  defp send_payout(_player_id, _amount), do: :ok

  # `put_character/2` 仅暂存（`private.update_character`）；同批多次改须读暂存后的。
  defp current(conn), do: conn.private.update_character || conn.character

  defp bet_usage, do: "庄家讥笑道：哪里有你那样赌钱的？\n"
end

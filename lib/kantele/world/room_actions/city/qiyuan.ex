defmodule Kantele.World.RoomActions.City.Qiyuan do
  @moduledoc """
  P5-9 #9 一次性场景：棋苑围棋 / 五子棋对局（房间层）。

  忠实移植自 `d/city/qiyuan/qiyuan2.c`（qiyuan3/4 同构），注册
  `city:qiyuan2` / `city:qiyuan3` / `city:qiyuan4` 三间棋室（UCL 已由转换器写出
  `actions = { sit/leave/play/pass/new/undo/refresh }`，零 UCL 改动）。

  棋盘规则见纯逻辑模块 `Kantele.World.Weiqi`（`no_qi`/`remove_block`/`eat`/
  `weiqi_rule`/`wuzi_rule`/`translate`/`new_game`/`undo`/`render`）。本模块只做
  「座位 / 轮次 / 房 state / 文案」的接线。

  ## 房 state `"qiyuan"`

      %{seats: %{black: %{id, name} | nil, white: %{id, name} | nil},
        game: nil | Weiqi.state,
        action: nil | 1}

  玩家自己的座位记在 `meta.temp["weiqi_seat"]`（`"black"`/`"white"`，对应 LPC
  `set_temp("weiqi_seat", arg)`）。

  ## 各动词（LPC 判定链逐条对齐）

  - `sit <black|white>`：已坐→「你已经坐着了」；无/非法色→「你想玩黑棋还是白棋？」；
    位子有人→「这个位子上已经有人了！」；否则入座 + vision「坐上了黑色的石凳」。
  - `leave`：未坐→「你没有在下棋」；否则 vision「不想再下了，站了起来」+ 清座 + 弃局。
  - `pass`：未坐→「你没有在下棋」；否则 vision「抛下棋子…我输了」+ 清座 + 弃局。
  - `new [-5] [-b<N>] [-h<N>]`：未坐→「你还没坐好呐」；缺对手→「还没有对手呐」；
    解析参数开盘（`Weiqi.new_game/3`）+ 播盘 + 「现在轮到黑方/白方<名>走棋」。
  - `play <coord>`：旁观→「你是旁观者，怎么好意思瞎指挥？」；未开局→「还没新开一局
    棋呐」；非本手→「还没轮到你走棋」；坐标错→「你要下在哪里？」；占位/打劫/禁入
    各文案；成功则播上一步 + 换手/胜负。
  - `undo`：五子棋悔棋（LPC 顺序：旁观/未开局/非五子棋/一步没走/非本手/已悔过）。
    注意 LPC 的「上一步」文案取的是**悔棋前**的 `turn` 颜色（`if (turn=="black")`
    先判后翻），与 `refresh` 取「对方颜色」的写法**不一致**——本模块两处都逐字
    保留，不做「修正」。
  - `refresh`：私发当前盘 + 上一步 + 轮到谁。

  ## 与 LPC 的差异（已记）

  - LPC `message_vision("…$N…", player)` 会把「轮到谁」里的 `$N` 对本人渲染成
    「你」；本模块用 `broadcast_vision` 写死玩家名（第三人称），对本人少一处
    「你」的渲染差异（其余文案一致）。
  - LPC `check_players` 每 3 秒清理掉线玩家的座位；本模块**未起常驻定时器**，
    座位在 `leave`/`pass` 前保留（掉线占位为已知缺口，@todo 接入房间在线校验）。
  - `qiyuan1` 大厅的 `valid_leave`（邻室开局则禁入）与棋室 `valid_leave`（坐着不能
    走）依赖移动命令侧消费 `valid_leave`，本引擎该链路未接线（同宴席缺口）。
  """

  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.Weiqi

  @state_key "qiyuan"

  @rooms ~w(city:qiyuan2 city:qiyuan3 city:qiyuan4)

  # ---- 分发 -----------------------------------------------------------------

  @impl true
  def run(%{character: nil}, _params), do: :not_handled

  def run(conn, %{room_id: room_id, verb: verb, trailing: trailing}) when is_binary(room_id) do
    if room_id in @rooms do
      arg = to_string(trailing || "")

      case verb do
        "do_sit" -> do_sit(conn, room_id, String.trim(arg))
        "do_leave" -> do_leave(conn, room_id)
        "do_pass" -> do_pass(conn, room_id)
        "do_new" -> do_new(conn, room_id, String.trim(arg))
        "do_play" -> do_play(conn, room_id, String.trim(arg))
        "do_undo" -> do_undo(conn, room_id)
        "do_refresh" -> do_refresh(conn, room_id)
        _ -> :not_handled
      end
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  # ---- sit ------------------------------------------------------------------

  defp do_sit(conn, room_id, color) do
    character = current(conn)
    st = load(room_id)

    cond do
      not is_nil(seat_of(conn)) ->
        fail(conn, "你已经坐着了。\n")

      color not in ["black", "white"] ->
        fail(conn, "你想玩黑棋还是白棋？\n")

      not is_nil(st.seats[color]) ->
        fail(conn, "这个位子上已经有人了！\n")

      true ->
        st = put_in(st.seats[color], %{id: character.id, name: character.name})
        save(room_id, st)

        conn
        |> put_seat(color)
        |> Helpers.broadcast_vision(
          room_id,
          if(color == "black", do: "$N坐上了黑色的石凳。\n", else: "$N坐上了白色的石凳。\n")
        )
    end
  end

  # ---- leave / pass ---------------------------------------------------------

  defp do_leave(conn, room_id) do
    case seat_of(conn) do
      nil ->
        fail(conn, "你没有在下棋。\n")

      _seat ->
        conn
        |> Helpers.broadcast_vision(room_id, "$N不想再下了，站了起来。\n")
        |> abandon(room_id)
    end
  end

  defp do_pass(conn, room_id) do
    case seat_of(conn) do
      nil ->
        fail(conn, "你没有在下棋。\n")

      _seat ->
        conn
        |> Helpers.broadcast_vision(room_id, "$N抛下棋子，站起来长叹一声，“我输了”\n")
        |> abandon(room_id)
    end
  end

  # ---- new ------------------------------------------------------------------

  defp do_new(conn, room_id, arg) do
    st = load(room_id)

    cond do
      is_nil(seat_of(conn)) ->
        fail(conn, "你还没坐好呐。\n")

      is_nil(st.seats["black"]) or is_nil(st.seats["white"]) ->
        fail(conn, "还没有对手呐。\n")

      true ->
        {wuzi, bsize, handicap} = parse_new_args(arg)
        game = Weiqi.new_game(bsize, wuzi, handicap)
        st = %{st | game: game, action: 1}
        save(room_id, st)

        conn
        |> Helpers.broadcast_vision(room_id, Weiqi.render(game))
        |> Helpers.broadcast_vision(room_id, turn_message(game, st))
    end
  end

  # ---- play -----------------------------------------------------------------

  defp do_play(conn, room_id, arg) do
    st = load(room_id)
    game = st.game
    seat = seat_of(conn)

    cond do
      is_nil(seat) ->
        fail(conn, "你是旁观者，怎么好意思瞎指挥？\n")

      is_nil(game) or game.status == Weiqi.status_not_playing() ->
        fail(conn, "还没新开一局棋呐。\n")

      seat != game.turn ->
        fail(conn, "还没轮到你走棋。\n")

      true ->
        mover = game.turn

        case Weiqi.play(game, arg) do
          {:error, :bad_coord} ->
            fail(conn, "你要下在哪里？\n")

          {:error, :occupied} ->
            fail(conn, "这个位置上已经有子了！\n")

          {:error, :jie_banned} ->
            fail(conn, "现在还没轮到你提劫！\n")

          {:error, :no_qi_banned} ->
            fail(conn, "这个位置是禁入点！\n")

          {:ok, game2, winning} ->
            st = %{st | game: game2}
            save(room_id, st)

            conn =
              Helpers.broadcast_vision(
                conn,
                room_id,
                "\n#{color_cn(mover)}棋上一步走在了#{arg}\n"
              )

            if winning do
              conn
              |> Helpers.broadcast_vision(room_id, Weiqi.render(game2))
              |> Helpers.broadcast_vision(room_id, "#{color_cn(mover)}方#{seat_name(st, mover)}胜。\n")
            else
              conn
              |> Helpers.broadcast_vision(room_id, Weiqi.render(game2))
              |> Helpers.broadcast_vision(room_id, turn_message(game2, st))
            end
        end
    end
  end

  # ---- undo -----------------------------------------------------------------

  defp do_undo(conn, room_id) do
    st = load(room_id)
    game = st.game
    seat = seat_of(conn)

    cond do
      is_nil(seat) ->
        fail(conn, "你是旁观者，怎么好意思瞎指挥？\n")

      is_nil(game) or game.status == Weiqi.status_not_playing() ->
        fail(conn, "还没新开一局棋呐。\n")

      game.status != Weiqi.status_wuzi() ->
        fail(conn, "目前只提供五子棋的悔棋功能。\n")

      game.started == 0 ->
        fail(conn, "一步都没走，悔什么棋。\n")

      seat != game.turn ->
        fail(conn, "要悔棋也得跟人家商量一下呀。\n")

      game.undoed == 1 ->
        fail(conn, "一次只能悔一步棋。\n")

      true ->
        {:ok, game2} = Weiqi.undo(game)
        st = %{st | game: game2}
        save(room_id, st)

        conn =
          if game2.lastmove != "" do
            Helpers.broadcast_vision(
              conn,
              room_id,
              "\n#{color_cn(game.turn)}棋上一步走在了#{game2.lastmove}\n"
            )
          else
            conn
          end

        conn
        |> Helpers.broadcast_vision(room_id, Weiqi.render(game2))
        |> Helpers.broadcast_vision(room_id, turn_message(game2, st))
    end
  end

  # ---- refresh --------------------------------------------------------------

  defp do_refresh(conn, room_id) do
    st = load(room_id)
    game = st.game

    cond do
      is_nil(game) or game.status == Weiqi.status_not_playing() ->
        fail(conn, "棋盘上是空的。\n")

      true ->
        conn =
          if game.started == 1 and game.lastmove != "" do
            Helpers.render_to_player(
              conn,
              "\n#{color_cn(other(game.turn))}棋上一步走在了#{game.lastmove}\n"
            )
          else
            conn
          end

        conn
        |> Helpers.render_to_player(Weiqi.render(game))
        |> Helpers.render_to_player(turn_message(game, st))
    end
  end

  # ---- 座位 / 房 state ------------------------------------------------------

  defp seat_of(conn) do
    character = current(conn)
    temp = (character.meta && character.meta.temp) || %{}

    case Map.get(temp, "weiqi_seat") do
      seat when seat in ["black", "white"] -> seat
      _ -> nil
    end
  end

  defp put_seat(conn, color) do
    character = current(conn)
    temp = Map.put(character.meta.temp || %{}, "weiqi_seat", color)
    put_character(conn, %{character | meta: %{character.meta | temp: temp}})
  end

  defp clear_seat(conn) do
    character = current(conn)
    temp = Map.delete(character.meta.temp || %{}, "weiqi_seat")
    put_character(conn, %{character | meta: %{character.meta | temp: temp}})
  end

  # leave/pass 共用：清本人座位 + 弃局（status 归 not_playing）
  defp abandon(conn, room_id) do
    seat = seat_of(conn)
    st = load(room_id)

    seats = if seat, do: Map.put(st.seats, seat, nil), else: st.seats
    save(room_id, %{st | seats: seats, game: nil, action: nil})

    clear_seat(conn)
  end

  defp load(room_id) do
    case Room.get_state_by_id(room_id, @state_key) do
      %{seats: seats} = st ->
        %{st | seats: Map.merge(%{"black" => nil, "white" => nil}, seats || %{})}

      _ ->
        %{seats: %{"black" => nil, "white" => nil}, game: nil, action: nil}
    end
  end

  defp save(room_id, st), do: Room.put_state_by_id(room_id, @state_key, st)

  # ---- 参数解析 / 文案 ------------------------------------------------------

  # LPC do_new：-5 五子棋；-b<N> 棋盘大小（1..19，越界 19）；-h<N> 让子（2..9，越界 0）
  defp parse_new_args(arg) do
    arg
    |> String.split(" ", trim: true)
    |> Enum.reduce({false, 19, 0}, fn tok, {wuzi, bsize, handicap} ->
      cond do
        String.starts_with?(tok, "-5") -> {true, bsize, handicap}
        String.starts_with?(tok, "-b") -> {wuzi, clamp_bsize(int_after(tok)), handicap}
        String.starts_with?(tok, "-h") -> {wuzi, bsize, clamp_handicap(int_after(tok))}
        true -> {wuzi, bsize, handicap}
      end
    end)
  end

  defp int_after(tok) do
    case Integer.parse(String.slice(tok, 2..-1)) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp clamp_bsize(n) when n >= 1 and n <= 19, do: n
  defp clamp_bsize(_), do: 19

  defp clamp_handicap(n) when n >= 2 and n <= 9, do: n
  defp clamp_handicap(_), do: 0

  defp turn_message(game, st) do
    "现在轮到#{color_cn(game.turn)}方#{seat_name(st, game.turn)}走棋。\n"
  end

  defp seat_name(st, color) do
    case st.seats[color] do
      %{name: name} -> name
      _ -> "?"
    end
  end

  defp color_cn("black"), do: "黑"
  defp color_cn("white"), do: "白"

  defp other("black"), do: "white"
  defp other("white"), do: "black"

  defp fail(conn, text), do: Helpers.render_to_player(conn, text)

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

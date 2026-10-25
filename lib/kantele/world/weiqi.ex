defmodule Kantele.World.Weiqi do
  @moduledoc """
  P5-9 #9 一次性场景：棋苑围棋 / 五子棋引擎（纯逻辑，无副作用）。

  忠实移植自 `d/city/qiyuan/qiyuan2.c`（qiyuan3/4 同构）的棋盘算法：

  - `no_qi/3`：某子所在「块」是否有气（洪泛填气）。
  - `remove_block/3`：提掉 (x,y) 所在同色块，返回提子数与新盘。
  - `eat/3`：落子后检查四邻死子并提掉（LPC `eat`）。
  - `weiqi_rule/3`：围棋合法判定（占位 / 打劫 / 禁入点 / 正常落子）。
  - `wuzi_rule/3`：五子棋落子 + 五连判定（四方向）。
  - `translate/2`：坐标解析（ASCII 字母 A-S / a-s + 数字 1-19，字节长度 2..3，
    与 LPC `translate_position` 逐字对齐）。
  - `new_game/3`：开盘（棋盘大小 / 五子棋 / 让子，含 `h_list` 让子点）。
  - `undo/1`：五子棋悔棋（一步）。
  - `render/1`：棋盘渲染（`show_game` 的框线 + ●○ + 全角坐标）。

  棋盘是长度 `bsize*bsize` 的列表，值：`0` 空 / `1` 黑 / `2` 白。
  状态为普通 map（见 `new_game/3`），便于存入房 state 并做纯函数测试。

  ## 与 LPC 的差异

  - LPC 用模块级可变 `game[]`/`jie_flag` 等；这里全部收敛进 state map，
    每个函数返回新 state（纯函数，可重入、可测）。
  - 颜色/状态常量与 LPC `#define` 同值，便于逐条对照。
  """

  @black 1
  @white 2
  @blank 0

  # 状态（LPC WQ_*）
  @status_not_playing 3
  @status_playing 4
  @status_wuzi 7
  @jie_possible 5
  @no_jie 6

  # 让子点（LPC h_list，19 路）
  @h_list [
    3 * 19 + 3,
    15 * 19 + 15,
    15 * 19 + 3,
    3 * 19 + 15,
    3 * 19 + 9,
    15 * 19 + 9,
    9 * 19 + 3,
    9 * 19 + 15
  ]

  # 渲染用坐标（LPC xindex/yindex 全角）
  @xindex ~w(Ａ Ｂ Ｃ Ｄ Ｅ Ｆ Ｇ Ｈ Ｉ Ｊ Ｋ Ｌ Ｍ Ｎ Ｏ Ｐ Ｑ Ｒ Ｓ)
  @yindex ~w(⑴ ⑵ ⑶ ⑷ ⑸ ⑹ ⑺ ⑻ ⑼ ⑽ ⑾ ⑿ ⒀ ⒁ ⒂ ⒃ ⒄ ⒅ ⒆)
  @nindex Enum.map(1..19, &Integer.to_string/1)

  # 坐标字母（LPC Ucase/lcase，仅 ASCII A-S / a-s）
  @ucase ~w(A B C D E F G H I J K L M N O P Q R S)
  @lcase ~w(a b c d e f g h i j k l m n o p q r s)

  def black, do: @black
  def white, do: @white
  def blank, do: @blank
  def status_not_playing, do: @status_not_playing
  def status_playing, do: @status_playing
  def status_wuzi, do: @status_wuzi

  # ---- 开盘 -----------------------------------------------------------------

  @doc """
  开盘。`wuzi` 为真下五子棋（LPC `-5`），否则围棋。
  `handicap` 仅在 19 路围棋下生效（LPC：`bsize!=19 || status!=WQ_PLAYING` 则清零）。
  """
  def new_game(bsize \\ 19, wuzi \\ false, handicap \\ 0) do
    status = if wuzi, do: @status_wuzi, else: @status_playing
    handicap = if bsize != 19 or status != @status_playing, do: 0, else: handicap

    board = List.duplicate(@blank, bsize * bsize)
    {board, turn} = place_handicap(board, bsize, handicap)

    %{
      bsize: bsize,
      board: board,
      status: status,
      turn: turn,
      handicap: handicap,
      jie_flag: @no_jie,
      jie_x_ban: nil,
      jie_y_ban: nil,
      started: 0,
      undoed: 0,
      lastmove: "",
      lastlastmove: ""
    }
  end

  defp place_handicap(board, _bsize, 0), do: {board, "black"}

  defp place_handicap(board, 19, handicap) when handicap > 0 do
    board =
      if rem(handicap, 2) == 1 do
        board = put(board, 9 * 19 + 9, @black)
        Enum.reduce(0..(handicap - 2)//1, board, fn i, b -> put(b, Enum.at(@h_list, i), @black) end)
      else
        Enum.reduce(0..(handicap - 1)//1, board, fn i, b -> put(b, Enum.at(@h_list, i), @black) end)
      end

    {board, "white"}
  end

  # ---- 坐标解析 -------------------------------------------------------------

  @doc """
  LPC `translate_position`：ASCII 字母 A-S/a-s + 数字 1-19。
  返回 `{:ok, x, y}`（0-based）或 `:error`。
  """
  def translate(s, bsize) when is_binary(s) do
    s = String.trim(s)

    if byte_size(s) < 2 or byte_size(s) > 3 do
      :error
    else
      <<c::binary-size(1), numstr::binary>> = s

      with x when not is_nil(x) <- letter_index(c, bsize),
           y when not is_nil(y) <- num_index(numstr, bsize) do
        {:ok, x, y}
      else
        _ -> :error
      end
    end
  end

  def translate(_s, _bsize), do: :error

  defp letter_index(c, bsize) do
    Enum.find_index(Enum.take(@ucase, bsize), &(&1 == c)) ||
      Enum.find_index(Enum.take(@lcase, bsize), &(&1 == c))
  end

  defp num_index(s, bsize) do
    Enum.find_index(Enum.take(@nindex, bsize), &(&1 == s))
  end

  # ---- 落子 -----------------------------------------------------------------

  @doc """
  落子（LPC `do_play` 的规则部分，不含轮次/座位校验——那在房间层）。

  返回 `{:ok, state, winning?}` 或 `{:error, reason}`，reason ∈
  `:bad_coord | :occupied | :jie_banned | :no_qi_banned`。
  """
  def play(state, coord) do
    case translate(coord, state.bsize) do
      :error ->
        {:error, :bad_coord}

      {:ok, x, y} ->
        result =
          if state.status == @status_wuzi do
            wuzi_rule(state, x, y)
          else
            weiqi_rule(state, x, y)
          end

        case result do
          {:error, reason} ->
            {:error, reason}

          {:ok, state2, winning} ->
            state3 = %{
              state2
              | started: 1,
                undoed: 0,
                lastlastmove: state.lastmove,
                lastmove: coord
            }

            if winning do
              {:ok, %{state3 | status: @status_not_playing}, true}
            else
              {:ok, %{state3 | turn: other(state.turn)}, false}
            end
        end
    end
  end

  # ---- 围棋规则 -------------------------------------------------------------

  defp weiqi_rule(state, x, y) do
    %{bsize: bsize, board: board, turn: turn} = state
    pos = x * bsize + y

    if at(board, pos) != @blank do
      {:error, :occupied}
    else
      color = if turn == "black", do: @black, else: @white
      board0 = put(board, pos, color)
      {board1, n, eat_pos} = eat(board0, bsize, x, y)

      cond do
        # n>1：提子多于一个，解劫
        n > 1 ->
          {:ok, %{state | board: board1, jie_flag: @no_jie, jie_x_ban: nil, jie_y_ban: nil}, false}

        # n==1：打劫判定
        n == 1 ->
          if state.jie_flag == @jie_possible and x == state.jie_x_ban and y == state.jie_y_ban do
            {:error, :jie_banned}
          else
            {ex, ey} = eat_pos
            {:ok, %{state | board: board1, jie_flag: @jie_possible, jie_x_ban: ex, jie_y_ban: ey},
             false}
          end

        # n==0：禁入点（自杀）
        true ->
          if no_qi(board1, bsize, x, y) do
            {:error, :no_qi_banned}
          else
            {:ok, %{state | board: board1, jie_flag: @no_jie, jie_x_ban: nil, jie_y_ban: nil}, false}
          end
      end
    end
  end

  # ---- 五子棋规则 -----------------------------------------------------------

  defp wuzi_rule(state, x, y) do
    %{bsize: bsize, board: board, turn: turn} = state
    pos = x * bsize + y

    if at(board, pos) != @blank do
      {:error, :occupied}
    else
      color = if turn == "black", do: @black, else: @white
      board = put(board, pos, color)
      {:ok, %{state | board: board}, wuzi_win?(board, bsize, x, y, color)}
    end
  end

  # 四方向（↘ ↗ ↑ →）五连
  defp wuzi_win?(board, bsize, x, y, color) do
    dirs = [{1, 1}, {-1, 1}, {1, 0}, {0, 1}]

    Enum.any?(dirs, fn {dx, dy} ->
      count =
        1 + count_dir(board, bsize, x, y, dx, dy, color) +
          count_dir(board, bsize, x, y, -dx, -dy, color)

      count >= 5
    end)
  end

  defp count_dir(board, bsize, x, y, dx, dy, color) do
    nx = x + dx
    ny = y + dy

    if nx >= 0 and nx < bsize and ny >= 0 and ny < bsize and
         at(board, nx * bsize + ny) == color do
      1 + count_dir(board, bsize, nx, ny, dx, dy, color)
    else
      0
    end
  end

  # ---- 气 / 提子 ------------------------------------------------------------

  # LPC no_qi：返回 true 表示该子所在块无气（禁入点）
  defp no_qi(board, bsize, x, y) do
    color = at(board, x * bsize + y)
    {_board, has_qi} = flood_qi(board, bsize, [{x, y}], MapSet.new(), color, false)
    not has_qi
  end

  defp flood_qi(board, _bsize, [], _seen, _color, has_qi), do: {board, has_qi}

  defp flood_qi(board, bsize, [{x, y} | rest], seen, color, has_qi) do
    if MapSet.member?(seen, {x, y}) do
      flood_qi(board, bsize, rest, seen, color, has_qi)
    else
      seen = MapSet.put(seen, {x, y})

      {rest, has_qi} =
        Enum.reduce(neighbors(x, y, bsize), {rest, has_qi}, fn {nx, ny}, {r, q} ->
          case at(board, nx * bsize + ny) do
            @blank -> {r, true}
            ^color -> {[{nx, ny} | r], q}
            _ -> {r, q}
          end
        end)

      flood_qi(board, bsize, rest, seen, color, has_qi)
    end
  end

  # LPC remove_block：提掉 (x,y) 同色块，返回 {新盘, 提子数}
  defp remove_block(board, bsize, x, y) do
    color = at(board, x * bsize + y)
    remove_flood(board, bsize, [{x, y}], MapSet.new(), color, 0)
  end

  defp remove_flood(board, _bsize, [], _seen, _color, count), do: {board, count}

  defp remove_flood(board, bsize, [{x, y} | rest], seen, color, count) do
    if MapSet.member?(seen, {x, y}) do
      remove_flood(board, bsize, rest, seen, color, count)
    else
      seen = MapSet.put(seen, {x, y})
      # 先取同色邻（用未改动前的盘判定），再落空
      nbrs = Enum.filter(neighbors(x, y, bsize), fn {nx, ny} -> at(board, nx * bsize + ny) == color end)
      board = put(board, x * bsize + y, @blank)
      remove_flood(board, bsize, nbrs ++ rest, seen, color, count + 1)
    end
  end

  # LPC eat：落子后提掉四邻死子，返回 {新盘, 提子总数, 最后被提位置 | nil}
  defp eat(board, bsize, x, y) do
    mycolor = at(board, x * bsize + y)
    opcolor = if mycolor == @black, do: @white, else: @black

    Enum.reduce(neighbors(x, y, bsize), {board, 0, nil}, fn {nx, ny}, {b, n, last} ->
      if at(b, nx * bsize + ny) == opcolor and no_qi(b, bsize, nx, ny) do
        {b2, cnt} = remove_block(b, bsize, nx, ny)
        {b2, n + cnt, {nx, ny}}
      else
        {b, n, last}
      end
    end)
  end

  defp neighbors(x, y, bsize) do
    [{x - 1, y}, {x + 1, y}, {x, y - 1}, {x, y + 1}]
    |> Enum.filter(fn {i, j} -> i >= 0 and i < bsize and j >= 0 and j < bsize end)
  end

  # ---- 悔棋（五子棋） -------------------------------------------------------

  @doc """
  LPC `do_undo` 的棋盘部分（座位/轮次校验在房间层）。
  返回 `{:ok, state}` 或 `{:error, reason}`，reason ∈
  `:not_playing | :not_wuzi | :not_started | :undoed`。
  """
  def undo(state) do
    cond do
      state.status == @status_not_playing -> {:error, :not_playing}
      state.status != @status_wuzi -> {:error, :not_wuzi}
      state.started == 0 -> {:error, :not_started}
      state.undoed == 1 -> {:error, :undoed}
      true ->
        case translate(state.lastmove, state.bsize) do
          {:ok, x, y} ->
            board = put(state.board, x * state.bsize + y, @blank)

            {lastmove, started} =
              if state.lastlastmove == "", do: {"", 0}, else: {state.lastlastmove, state.started}

            {:ok,
             %{
               state
               | board: board,
                 lastmove: lastmove,
                 started: started,
                 undoed: 1,
                 turn: other(state.turn)
             }}

          :error ->
            {:error, :not_started}
        end
    end
  end

  # ---- 渲染 -----------------------------------------------------------------

  @doc "LPC `show_game`：框线棋盘 + ●○ + 全角坐标。"
  def render(%{bsize: bsize, board: board}) do
    rows =
      Enum.map(0..(bsize - 1), fn i ->
        cells =
          Enum.map_join(0..(bsize - 1), fn j ->
            cell = at(board, i * bsize + j)

            cond do
              cell == @black -> "●"
              cell == @white -> "○"
              i == 0 and j == 0 -> "┌"
              i == 0 and j == bsize - 1 -> "┐"
              i == bsize - 1 and j == 0 -> "└"
              i == bsize - 1 and j == bsize - 1 -> "┘"
              i == 0 -> "┬"
              j == 0 -> "├"
              j == bsize - 1 -> "┤"
              i == bsize - 1 -> "┴"
              true -> "┼"
            end
          end)

        Enum.at(@xindex, i) <> "　" <> cells <> "\n"
      end)

    "\n" <> Enum.join(rows) <> "\n　　" <> Enum.join(Enum.take(@yindex, bsize)) <> "\n\n"
  end

  # ---- 小工具 ----------------------------------------------------------------

  defp at(board, i), do: Enum.at(board, i)
  defp put(board, i, v), do: List.replace_at(board, i, v)

  defp other("black"), do: "white"
  defp other("white"), do: "black"
end

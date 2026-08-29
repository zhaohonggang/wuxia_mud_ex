defmodule Kantele.World.Room.Qiyuan do
  @moduledoc """
  棋苑棋房（对应 ExKantele.World.Room.Qiyuan / qiyuan.ex）

  功能：
  - 围棋/五子棋对弈状态机
  - 座位管理（black/white）
  - 游戏状态存储（Game struct）
  - 命令分发 (sit/leave/play/pass/new/undo/refresh)
  - 消息广播
  - 定时清理
  """
  alias Kantele.World.Room
  alias Kantele.Scheduler
  alias Kalevala.Character.Conn

  # 常量（对应 qiyuan.ex 状态常量）
  @black 1
  @white 2
  @blank 0
  @aux_color 8
  @not_playing 3
  @playing 4
  @playing_wuzi 7
  @jie_possible 5
  @no_jie 6
  @winning 9
  @pos_occupied -2
  @jie_banned -3
  @no_qi_banned -4

  @handicap_stars [3 * 19 + 3, 15 * 19 + 15, 15 * 19 + 3, 3 * 19 + 15, 3 * 19 + 9, 15 * 19 + 9, 9 * 19 + 3, 9 * 19 + 15]

  # 坐标解析表
  @ucase ~w(A B C D E F G H I J K L M N O P Q R S)
  @lcase ~w(a b c d e f g h i j k l m n o p q r s)
  @numindex ~w(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19)
  @yindex ~w(⑴⑵⑶⑷⑸⑹⑺⑻⑼⑽⑾⑿⒀⒁⒂⒃⒄⒅⒆)
  @xindex ~w(ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳ)

  # 定义 Game struct 在最前面，避免循环依赖
  defmodule Game do
    @moduledoc "一局棋盘状态（不可变）"
    defstruct cells: %{},
              bsize: 19,
              turn: "black",
              status: 3,
              handicap: 0,
              jie_flag: 6,
              jie_x_ban: -1,
              jie_y_ban: -1,
              lastmove: "",
              lastlastmove: "",
              started: false,
              undoable: false

    def new(), do: %__MODULE__{}
  end

  defstruct [
    :id,
    :key,
    :zone_id,
    :name,
    :description,
    :map_color,
    :map_icon,
    :x,
    :y,
    :z,
    exits: [],
    features: [],
    flags: [],
    # 棋房专用字段
    game: nil,
    seats: %{"black" => nil, "white" => nil},
    players: %{}
  ]

  # 常量（对应 qiyuan.ex 状态常量）
  @black 1
  @white 2
  @blank 0
  @aux_color 8
  @not_playing 3
  @playing 4
  @playing_wuzi 7
  @jie_possible 5
  @no_jie 6
  @winning 9
  @pos_occupied -2
  @jie_banned -3
  @no_qi_banned -4

  @handicap_stars [3 * 19 + 3, 15 * 19 + 15, 15 * 19 + 3, 3 * 19 + 15, 3 * 19 + 9, 15 * 19 + 9, 9 * 19 + 3, 9 * 19 + 15]

  # 坐标解析表
  @ucase ~w(A B C D E F G H I J K L M N O P Q R S)
  @lcase ~w(a b c d e f g h i j k l m n o p q r s)
  @numindex ~w(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19)
  @yindex ~w(⑴⑵⑶⑷⑸⑹⑺⑻⑼⑽⑾⑿⒀⒁⒂⒃⒄⒅⒆)
  @xindex ~w(ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳ)

  # ==================== 坐标解析 ====================

  defp char_to_x(ch) do
    case Enum.find_index(@ucase, &(&1 == ch)) do
      nil -> Enum.find_index(@lcase, &(&1 == ch))
      i -> i
    end
  end

  @doc """
  解析 'd4' 式坐标 -> {:ok, x, y} | :error
  x 为列 (A..S, 0 基), y 为行 (1..19 -> 0 基)。
  """
  def translate_position(%Game{bsize: bsize}, s) when is_binary(s) do
    if byte_size(s) < 2 or byte_size(s) > 3 do
      :error
    else
      <<h::binary-size(1), t::binary>> = s
      x = char_to_x(h)
      y = pos_str_to_int(t)

      cond do
        x == nil -> :error
        y == nil -> :error
        x < 0 or x >= bsize -> :error
        y < 0 or y >= bsize -> :error
        true -> {:ok, x, y}
      end
    end
  end

  defp pos_str_to_int(s) do
    Enum.find_index(@numindex, &(&1 == s))
  end

  defp coord_string(%Game{}, x, y) do
    Enum.at(@lcase, x) <> Enum.at(@numindex, y)
  end

  defp neighbors(bsize, i, j) do
    [{i - 1, j}, {i + 1, j}, {i, j - 1}, {i, j + 1}]
    |> Enum.filter(fn {ni, nj} -> ni >= 0 and ni < bsize and nj >= 0 and nj < bsize end)
  end

  # ==================== 围棋：气与吃子 ====================

  @doc """
  判断含 (x,y) 的块的气是否为零（对照 no_qi/3）。
  board 为临时副本；返回 {否有气, 复原后的 board}。
  内部用 @aux_color 标记已访问，结束后将标记位复原为原色（对应 LPC blist 复原）。
  """
  def no_qi(bsize, board, x, y) do
    mycolor = Map.fetch!(board, x * bsize + y)
    # do_no_qi 返回 {qi, visited_positions}
    {qi, visited} = do_no_qi(bsize, board, mycolor, [x * bsize + y], [], false)
    board = Enum.reduce(visited, board, &Map.put(&2, &1, mycolor))
    {qi, board}
  end

  # 考虑：仅 mycolor 的位置会入栈并被标记 AUX，故复原为 mycolor 正确。
  defp do_no_qi(_bsize, _board, _mycolor, [], visited, qi), do: {qi, visited}

  defp do_no_qi(bsize, board, mycolor, [pos | rest], visited, qi) do
    i = div(pos, bsize)
    j = rem(pos, bsize)
    board = Map.put(board, pos, @aux_color)
    visited = [pos | visited]

    {board, qi, candidates} =
      neighbors(bsize, i, j)
      |> Enum.reduce({board, qi, []}, fn {ni, nj}, {bd, qf, cand} ->
        npos = ni * bsize + nj
        color = Map.get(bd, npos, @blank)

        cond do
          color == @blank -> {bd, true, cand}
          color == mycolor -> {bd, qf, [npos | cand]}
          true -> {bd, qf, cand}
        end
      end)

    if qi do
      {true, visited}
    else
      do_no_qi(bsize, board, mycolor, Enum.concat(candidates, rest), visited, qi)
    end
  end

  @doc "移除含 (x,y) 的块，返回 {移除数, 移除位置列表, 处理后的 board}"
  def remove_block(bsize, board, x, y) do
    color = Map.fetch!(board, x * bsize + y)
    do_remove(bsize, board, color, [x * bsize + y], [])
  end

  defp do_remove(_bsize, board, _color, [], removed), do: {length(removed), removed, board}

  defp do_remove(bsize, board, color, [pos | rest], removed) do
    i = div(pos, bsize)
    j = rem(pos, bsize)
    # 删除以彻底清空位置（空位 = 不在 map 中）
    board = Map.delete(board, pos)

    added =
      neighbors(bsize, i, j)
      |> Enum.filter(fn {ni, nj} -> Map.get(board, ni * bsize + nj) == color end)
      |> Enum.map(fn {ni, nj} -> ni * bsize + nj end)

    do_remove(bsize, board, color, Enum.concat(added, rest), [pos | removed])
  end

  @doc """
  落 (x,y) 后清走被吃的敌子。
  board 为【已含新子】的临时图。
  返回 {被吃子数, {x_eat, y_eat} | nil, 处理后 board}。
  """
  def eat(bsize, board, x, y) do
    mycolor = Map.fetch!(board, x * bsize + y)
    opcolor = if mycolor == @black, do: @white, else: @black

    neighbors(bsize, x, y)
    |> Enum.reduce({0, nil, board}, fn {ni, nj}, {num, le, bd} ->
      npos = ni * bsize + nj

      if Map.get(bd, npos) == opcolor do
        {has_qi, bd} = no_qi(bsize, bd, ni, nj)

        if not has_qi do
          {c, _removed, bd} = remove_block(bsize, bd, ni, nj)
          {num + c, {ni, nj}, bd}
        else
          {num, le, bd}
        end
      else
        {num, le, bd}
      end
    end)
  end

  # ==================== 围棋规则 ====================

  @doc "围棋落子合法性（weiqi_rule）。返回 {:ok, new_game} | {:error, code}"
  def weiqi_rule(%Game{} = g, x, y) do
    pos = x * g.bsize + y
    color = if g.turn == "black", do: @black, else: @white

    if Map.has_key?(g.cells, pos) do
      {:error, @pos_occupied}
    else
      board = Map.put(g.cells, pos, color)
      {n, eaten_pos, board} = eat(g.bsize, board, x, y)

      cond do
        n > 1 ->
          {:ok, %{g | cells: board, jie_flag: @no_jie}}

        n == 1 ->
          if g.jie_flag == @jie_possible and x == g.jie_x_ban and y == g.jie_y_ban do
            {:error, @jie_banned}
          else
            {ex, ey} = eaten_pos
            {:ok, %{g | cells: board, jie_flag: @jie_possible, jie_x_ban: ex, jie_y_ban: ey}}
          end

        true ->
          {has_qi, _} = no_qi(g.bsize, board, x, y)

          if not has_qi do
            {:error, @no_qi_banned}
          else
            {:ok, %{g | cells: board, jie_flag: @no_jie}}
          end
      end
    end
  end

  # ==================== 五子棋规则 ====================

  @doc "五子棋落子（wuzi_rule）。返回 {:ok, new_game, won?} | {:error, code}"
  def wuzi_rule(%Game{} = g, x, y) do
    pos = x * g.bsize + y

    if Map.has_key?(g.cells, pos) do
      {:error, @pos_occupied}
    else
      color = if g.turn == "black", do: @black, else: @white
      cells = Map.put(g.cells, pos, color)
      won? = five_in_row?(g, cells, x, y, color)
      {:ok, %{g | cells: cells}, won?}
    end
  end

  defp five_in_row?(g, cells, x, y, color) do
    [{1, 1}, {1, -1}, {1, 0}, {0, 1}]
    |> Enum.any?(fn {dx, dy} ->
      count_line(g, cells, x, y, dx, dy, color) + count_line(g, cells, x, y, -dx, -dy, color) - 1 >= 5
    end)
  end

  defp count_line(g, cells, x, y, dx, dy, color) do
    if x < 0 or x >= g.bsize or y < 0 or y >= g.bsize or Map.get(cells, x * g.bsize + y) != color do
      0
    else
      1 + count_line(g, cells, x + dx, y + dy, dx, dy, color)
    end
  end

  # ==================== 棋局控制 ====================

  @doc "开始新局（do_new）：解析 new [-5] [-bN] [-hN]"
  def new_game(%Game{} = g0, arg \\ "") do
    status = if String.contains?(arg, "-5"), do: @playing_wuzi, else: @playing
    bsize = parse_opt(arg, "-b", 19) |> clamp(1, 19)

    handicap =
      if bsize == 19 and status == @playing do
        case parse_opt(arg, "-h", 0) do
          h when h >= 2 and h <= 9 -> h
          _ -> 0
        end
      else
        0
      end

    cells = handicap_cells(handicap)
    turn = if handicap > 0, do: "white", else: "black"

    %{
      g0
      | cells: cells,
        bsize: bsize,
        status: status,
        handicap: handicap,
        turn: turn,
        jie_flag: @no_jie,
        lastmove: "",
        lastlastmove: "",
        started: false,
        undoable: false
    }
  end

  defp handicap_cells(0), do: %{}

  defp handicap_cells(h) do
    {center, rest} =
      if rem(h, 2) == 1 do
        {[9 * 19 + 9], h - 1}
      else
        {[], h}
      end

    Map.new(center ++ Enum.take(@handicap_stars, rest), &{&1, @black})
  end

  defp parse_opt(arg, prefix, default) do
    case Regex.run(~r/#{prefix}(\d+)/, arg) do
      [_, n] -> String.to_integer(n)
      _ -> default
    end
  end

  defp clamp(v, lo, hi), do: min(max(v, lo), hi)

  @doc "落子（do_play）：play <coord>。返回 {new_game, notif}"
  def play(%Game{} = g, arg) do
    case translate_position(g, arg) do
      :error ->
        {g, {:error, "你要下在哪里？"}}

      {:ok, x, y} ->
        do_play_move(g, x, y)
    end
  end

  defp do_play_move(%Game{status: @playing_wuzi} = g, x, y) do
    mv = coord_string(g, x, y)

    case wuzi_rule(g, x, y) do
      {:error, @pos_occupied} -> {g, {:error, "这个位置上已经有子了！"}}
      {:ok, ng, true} -> {mark_played(ng, mv), {:win, winner(g.turn)}}
      {:ok, ng, false} -> {next_turn(mark_played(ng, mv)), {:moved, mv}}
    end
  end

  defp do_play_move(g, x, y) do
    mv = coord_string(g, x, y)

    case weiqi_rule(g, x, y) do
      {:error, @pos_occupied} -> {g, {:error, "这个位置上已经有子了！"}}
      {:error, @jie_banned} -> {g, {:error, "现在还没轮到你提劫！"}}
      {:error, @no_qi_banned} -> {g, {:error, "这个位置是禁入点！"}}
      {:ok, ng} -> {next_turn(mark_played(ng, mv)), {:moved, mv}}
    end
  end

  defp mark_played(%Game{} = g, move) do
    %{g | started: true, undoable: false, lastlastmove: g.lastmove, lastmove: move}
  end

  defp winner("black"), do: "黑方"
  defp winner("white"), do: "白方"

  defp next_turn(%Game{turn: "black"} = g), do: %{g | turn: "white"}
  defp next_turn(%Game{turn: "white"} = g), do: %{g | turn: "black"}

  @doc "悔棋（do_undo，仅五子棋）"
  def undo(%Game{} = g) do
    cond do
      g.status == @not_playing -> {g, {:error, "还没新开一局棋呐。"}}
      g.status != @playing_wuzi -> {g, {:error, "目前只提供五子棋的悔棋功能。"}}
      not g.started -> {g, {:error, "一步都没走，悔什么棋。"}}
      g.undoable -> {g, {:error, "一次只能悔一步棋。"}}
      true ->
        case translate_position(g, g.lastmove) do
          :error -> {g, {:error, "无法定位上一步。"}}
          {:ok, x, y} ->
            cells = Map.delete(g.cells, x * g.bsize + y)
            ng = %{g | cells: cells, undoable: true, lastmove: g.lastlastmove}
            {next_turn(ng), {:ok, "悔棋成功。"}}
        end
    end
  end

  # ==================== 渲染 ====================

  @doc "渲染棋盘（对应 show_game）"
  def show_game(%Game{} = g) do
    rows =
      Enum.map_join(0..(g.bsize - 1), "\n", fn i ->
        Enum.map_join(0..(g.bsize - 1), "", fn j -> render_cell(g, i, j) end)
      end)

    "\n" <>
      rows <>
      "\n\n　　" <>
      (Enum.take(@yindex, g.bsize) |> Enum.join("")) <>
      "\n\n"
  end

  defp render_cell(%Game{} = g, i, j) do
    case Map.get(g.cells, i * g.bsize + j) do
      @black -> "●"
      @white -> "○"
      _ -> render_empty(g, i, j)
    end
  end

  defp render_empty(g, i, j) do
    b = g.bsize - 1

    cond do
      i == 0 and j == 0 -> "┌"
      i == 0 and j == b -> "┐"
      i == b and j == 0 -> "└"
      i == b and j == b -> "┘"
      i == 0 -> "┬"
      j == 0 -> "├"
      j == b -> "┤"
      i == b -> "┴"
      true -> "┼"
    end
  end
end
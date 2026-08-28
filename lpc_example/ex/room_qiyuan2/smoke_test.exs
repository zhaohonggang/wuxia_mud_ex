alias ExKantele.World.Room.Qiyuan, as: Q
alias Q.Game

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end
put = fn x, y -> x * 19 + y end

# ---- coordinate parsing ----
ok.("tr_d4", Q.translate_position(%Game{bsize: 19}, "d4"), {:ok, 3, 3})
ok.("tr_D4", Q.translate_position(%Game{bsize: 19}, "D4"), {:ok, 3, 3})
ok.("tr_d19", Q.translate_position(%Game{bsize: 19}, "d19"), {:ok, 3, 18})
ok.("tr_a1", Q.translate_position(%Game{bsize: 19}, "a1"), {:ok, 0, 0})
ok.("tr_s19", Q.translate_position(%Game{bsize: 19}, "s19"), {:ok, 18, 18})
ok.("tr_bad", Q.translate_position(%Game{bsize: 19}, "zz"), :error)
ok.("tr_short", Q.translate_position(%Game{bsize: 19}, "d"), :error)
ok.("tr_oob9", Q.translate_position(%Game{bsize: 9}, "s9"), :error)

# ---- new_game ----
g = Q.new_game(%Game{})
ok.("ng_bsize", g.bsize, 19)
ok.("ng_status", g.status, 4)      # @playing
ok.("ng_turn", g.turn, "black")
ok.("ng_started", g.started, false)
ok.("ng_cells", g.cells, %{})
g5 = Q.new_game(%Game{}, "-5")
ok.("ng5_status", g5.status, 7)    # @playing_wuzi
g9 = Q.new_game(%Game{}, "-b9")
ok.("ng9_bsize", g9.bsize, 9)

# ---- weiqi: normal safe move -> ok, jie reset ----
case Q.weiqi_rule(g, 9, 9) do
  {:ok, ng} ->
    ok.("wq_ok_cell", Map.has_key?(ng.cells, put.(9, 9)), true)
    ok.("wq_ok_jie", ng.jie_flag, 6)     # @no_jie
  other -> ok.("wq_ok_err", other, :expected_ok)
end

# ---- weiqi: occupied point ----
occ = %{put.(3, 3) => 1}
ok.("wq_occupied", Q.weiqi_rule(%Game{bsize: 19, cells: occ, turn: "black"}, 3, 3), {:error, -2})

# ---- weiqi: suicide banned ----
# white at (1,0),(0,1); black to play (0,0): both on-board neighbors white,
# neither captured -> no qi -> banned
su = %{put.(1, 0) => 2, put.(0, 1) => 2}
ok.("wq_suicide", Q.weiqi_rule(%Game{bsize: 19, cells: su, turn: "black"}, 0, 0), {:error, -4})

# ---- no_qi ----
# white at (9,9) surrounded by 4 black -> no qi
surrounded = %{
  put.(8, 9) => 1, put.(10, 9) => 1, put.(9, 8) => 1, put.(9, 10) => 1, put.(9, 9) => 2
}
ok.("noqi_true", elem(Q.no_qi(19, surrounded, 9, 9), 0), false)   # has_qi=false
free = %{put.(9, 9) => 2}
ok.("noqi_false", elem(Q.no_qi(19, free, 9, 9), 0), true)         # has_qi=true

# ---- eat: capture a lone white stone ----
pre = %{
  put.(8, 9) => 1, put.(10, 9) => 1, put.(9, 8) => 1, put.(9, 9) => 2
}
cells_pre = Map.put(pre, put.(9, 10), 1)
{n, eaten, _b} = Q.eat(19, cells_pre, 9, 10)
ok.("eat_count", n, 1)
ok.("eat_pos", eaten, {9, 9})

# ---- remove_block ----
rb = %{put.(9, 9) => 2, put.(9, 8) => 2, put.(8, 9) => 2}
{c, removed, _r} = Q.remove_block(19, rb, 9, 9)
ok.("rm_count", c, 3)
ok.("rm_has", MapSet.member?(MapSet.new(removed), put.(8, 9)), true)

# ---- wuzi win ----
wz1 = %Game{bsize: 19, status: 7, turn: "black",
            cells: Enum.map(0..3, fn i -> {5 + i, 5} end)
              |> Map.new(fn {x, y} -> {put.(x, y), 1} end)}
{:ok, _, won?} = Q.wuzi_rule(wz1, 9, 5)
ok.("wz_win", won?, true)
wz2 = %Game{bsize: 19, status: 7, turn: "black",
            cells: Enum.map(0..2, fn i -> {5 + i, 5} end)
              |> Map.new(fn {x, y} -> {put.(x, y), 1} end)}
{:ok, _, won2?} = Q.wuzi_rule(wz2, 4, 5)
ok.("wz_nowin", won2?, false)
wzocc = %Game{bsize: 19, status: 7, turn: "black", cells: %{put.(4, 5) => 1}}
ok.("wz_occupied", Q.wuzi_rule(wzocc, 4, 5), {:error, -2})

# ---- play: normal move returns moved ----
g0 = Q.new_game(%Game{})
{p1, n1} = Q.play(g0, "d4")
ok.("play_moved", match?({:moved, _}, n1), true)
ok.("play_cell", Map.has_key?(p1.cells, put.(3, 3)), true)
ok.("play_turn", p1.turn, "white")
{p2, _} = Q.play(p1, "d5")
ok.("play_turn2", p2.turn, "black")
{_, nbad} = Q.play(g0, "zz")
ok.("play_bad", nbad, {:error, "你要下在哪里？"})

# ---- undo (wuzi only) ----
gu = Q.new_game(%Game{}, "-5")
{gu1, _} = Q.play(gu, "d4")
{gu2, _} = Q.play(gu1, "d5")
{gundone, unotif} = Q.undo(gu2)
ok.("undo_ok", match?({:ok, _}, unotif), true)
ok.("undo_removed", Map.has_key?(gundone.cells, put.(3, 4)), false)  # d5 removed in undone game
ok.("undo_lastmove", gundone.lastmove, "d4")
ok.("undo_undoable", gundone.undoable, true)
gngo = Q.new_game(%Game{})
{gngo1, _} = Q.play(gngo, "d4")
{_, ngonotif} = Q.undo(gngo1)
ok.("undo_go_err", match?({:error, _}, ngonotif), true)

IO.puts("done")

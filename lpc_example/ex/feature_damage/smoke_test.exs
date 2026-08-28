alias ExKantele.World.Feature.Damage, as: D

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

init_state = fn ->
  %{damage: %{last_damage_from: nil, last_damage_name: nil, defeated_by: nil,
              defeated_by_who: nil, ghost: false, defeat_player: []}}
end

# ---- init_feature / getters ----
st = D.init_feature(%{})
ok.("init_ghost", st.damage.ghost, false)
ok.("init_defeat_list", st.damage.defeat_player, [])
ok.("getter_last_damage_from", D.last_damage_from(st), nil)
st2 = %{damage: %{last_damage_from: "A", last_damage_name: "Ann", defeated_by: "B", defeated_by_who: "Bob", ghost: true, defeat_player: []}}
ok.("getter_ghost", D.is_ghost(st2), true)
ok.("getter_defeated_by", D.defeated_by(st2), "B")

# ---- receive_damage ----
{:ok, p} = D.receive_damage(init_state.(), %{"jing" => 100}, "jing", 30)
ok.("dmg_jing", p["jing"], 70)
{:ok, p2} = D.receive_damage(init_state.(), %{"qi" => 50}, "qi", 50)
ok.("dmg_qi_zero", p2["qi"], 0)
{:ok, p3} = D.receive_damage(init_state.(), %{"jing" => 10}, "jing", 999)
ok.("dmg_clamp_zero", p3["jing"], 0)
{:ok, p4} = D.receive_damage(init_state.(), %{"jing" => 100}, "jing", 0)
ok.("dmg_zero_nochange", p4["jing"], 100)
{err1, _} = D.receive_damage(init_state.(), %{"jing" => 100}, "jing", -5)
ok.("dmg_neg_error", err1, :error)
{err2, _} = D.receive_damage(init_state.(), %{"jing" => 100}, "nope", 5)
ok.("dmg_bad_type", err2, :error)
# with who (damage >150 triggers improve_craze, stub no-op; still returns player)
{:ok, p5} = D.receive_damage(init_state.(), %{"jing" => 300}, "jing", 160, %{id: "w", name: "Wally"})
ok.("dmg_with_who", p5["jing"], 140)

# ---- receive_wound ----
{:ok, q1} = D.receive_wound(init_state.(), %{"qi" => 100, "eff_qi" => 100}, "qi", 30)
ok.("wound_eff", q1["eff_qi"], 70)
ok.("wound_qi_clamped", q1["qi"], 70)
{:ok, q2} = D.receive_wound(init_state.(), %{"qi" => 60, "eff_qi" => 100}, "qi", 30)
ok.("wound_eff2", q2["eff_qi"], 70)
ok.("wound_qi_kept", q2["qi"], 60)
{err3, _} = D.receive_wound(init_state.(), %{"qi" => 100, "eff_qi" => 100}, "qi", -1)
ok.("wound_neg_error", err3, :error)
{err4, _} = D.receive_wound(init_state.(), %{"qi" => 100, "eff_qi" => 100}, "nei", 1)
ok.("wound_bad_type", err4, :error)

# ---- receive_heal ----
{:ok, h1} = D.receive_heal(init_state.(), %{"jing" => 50, "eff_jing" => 100}, "jing", 20)
ok.("heal_plus", h1["jing"], 70)
{:ok, h2} = D.receive_heal(init_state.(), %{"jing" => 90, "eff_jing" => 100}, "jing", 20)
ok.("heal_cap_eff", h2["jing"], 100)
{err5, _} = D.receive_heal(init_state.(), %{"jing" => 50, "eff_jing" => 100}, "jing", -1)
ok.("heal_neg_error", err5, :error)

# ---- receive_curing ----
{:ok, c1} = D.receive_curing(init_state.(), %{"eff_qi" => 70, "max_qi" => 100}, "qi", 20)
ok.("curing_eff", c1["eff_qi"], 90)
{:ok, c2} = D.receive_curing(init_state.(), %{"eff_qi" => 90, "max_qi" => 100}, "qi", 20)
ok.("curing_cap_max", c2["eff_qi"], 100)
{err6, _} = D.receive_curing(init_state.(), %{"eff_qi" => 70, "max_qi" => 100}, "qi", -1)
ok.("curing_neg_error", err6, :error)

# ---- capacity ----
ok.("food_base", D.max_food_capacity(init_state.(), %{str: 10}), 200)
ok.("food_tianshu", D.max_food_capacity(init_state.(), %{str: 10, has: %{"skybook/item/tianshu2" => true}}), 500)
ok.("food_greedy", D.max_food_capacity(init_state.(), %{str: 10, has: %{"special_skill/greedy" => true}}), 700)
ok.("food_both", D.max_food_capacity(init_state.(), %{str: 10, has: %{"skybook/item/tianshu2" => true, "special_skill/greedy" => true}}), 1000)
ok.("water_base", D.max_water_capacity(init_state.(), %{str: 20}), 300)
ok.("water_tianshu", D.max_water_capacity(init_state.(), %{str: 20, has: %{"skybook/item/tianshu2" => true}}), 600)

# ---- dps_count ----
ok.("dps_none", D.dps_count(%{damage: %{defeat_player: []}}), 0)
ok.("dps_two_living", D.dps_count(%{damage: %{defeat_player: [%{id: 1}, %{id: 2}]}}), 2)
ok.("dps_one_dead", D.dps_count(%{damage: %{defeat_player: [%{id: 1, living: false}, %{id: 2}]}}), 1)

# ---- record_dp ----
rdp = %{damage: %{defeat_player: []}}
res1 = D.record_dp(rdp, %{want_kill: ["x"]}, %{id: "x"})
ok.("record_added", Enum.map(res1.damage.defeat_player, &(&1.id)), ["x"])
res2 = D.record_dp(rdp, %{want_kill: ["y"]}, %{id: "x"})
ok.("record_not_wantkill", res2.damage.defeat_player, [])
res3 = D.record_dp(%{damage: %{defeat_player: [%{id: "x"}]}}, %{want_kill: ["x"]}, %{id: "x"})
ok.("record_no_dup", Enum.count(res3.damage.defeat_player, &(&1.id == "x")), 1)

# ---- remove_dp ----
r4 = D.remove_dp(%{damage: %{defeat_player: [%{id: 1}]}}, nil, nil)
ok.("remove_all", r4.damage.defeat_player, [])
r5 = D.remove_dp(%{damage: %{defeat_player: [%{id: 1}, %{id: 2}]}}, nil, %{id: 1})
ok.("remove_one", Enum.map(r5.damage.defeat_player, &(&1.id)), [2])

IO.puts("done")

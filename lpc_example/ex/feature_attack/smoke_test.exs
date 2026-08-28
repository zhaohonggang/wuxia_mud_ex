alias ExKantele.World.Feature.Attack, as: A

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

ob1 = %{id: "e1", name: "Enemy1", environment_id: "room_a", living: true, is_player: true}
ob2 = %{id: "e2", name: "Enemy2", environment_id: "room_a", living: true, is_player: true}

# build an attack state directly (init_feature overwrites the attack map)
mk = fn kwargs ->
  defaults = %{killer: [], want_kills: [], enemy: [], next_action: nil, default_object: nil, default_function: nil, competitor: nil}
  %{attack: Map.merge(defaults, kwargs)}
end

# ---------------- init_feature ----------------
base = A.init_feature(%{})
ak = base.attack
ok.("init_has_killer", Map.has_key?(ak, :killer), true)
ok.("init_has_want", Map.has_key?(ak, :want_kills), true)
ok.("init_has_enemy", Map.has_key?(ak, :enemy), true)
ok.("init_killer_empty", ak.killer, [])
ok.("init_competitor_nil", ak.competitor, nil)

# ---------------- getters ----------------
s1 = mk.(%{killer: ["k1"], want_kills: ["w1"], enemy: [ob1], default_object: "o", default_function: "f", competitor: "c1"})
ok.("get_enemies", A.get_enemies(s1), [ob1])
ok.("get_killers", A.get_killers(s1), ["k1"])
ok.("get_want_kills", A.get_want_kills(s1), ["w1"])
ok.("get_default_action", A.get_default_action(s1), %{"o" => "f"})

# ---------------- is_fighting ----------------
ok.("fight_empty", A.is_fighting(base), false)
ok.("fight_any", A.is_fighting(s1), true)
ok.("fight_ob_present", A.is_fighting(s1, ob1), true)
ok.("fight_ob_absent", A.is_fighting(s1, %{id: "zzz"}), false)

# ---------------- is_killing ----------------
ok.("kill_empty_state", A.is_killing(base, nil), false)
ok.("kill_binary", A.is_killing(s1, "k1"), true)
ok.("kill_binary_absent", A.is_killing(s1, "nope"), false)
ok.("kill_map", A.is_killing(s1, %{id: "k1"}), true)
kstate = mk.(%{killer: ["x"]})
ok.("kill_nil_has", A.is_killing(kstate, nil), true)

# ---------------- is_want_kill ----------------
ok.("want_present", A.is_want_kill(s1, "w1"), true)
ok.("want_absent", A.is_want_kill(s1, "nope"), false)

# ---------------- update_killer ----------------
Process.put({:find_player, "present"}, ob1)
Process.put({:find_player, "ghost"}, nil)
uk = mk.(%{killer: ["gone", "present"], want_kills: ["present", "ghost"]})
ukr = A.update_killer(uk)
ok.("update_want", ukr.attack.want_kills, ["present"])
ok.("update_killer", ukr.attack.killer, ["gone"])
Process.delete({:find_player, "present"})
Process.delete({:find_player, "ghost"})

# ---------------- remove_all_want / remove_all_killer ----------------
rw = mk.(%{killer: ["k1"], want_kills: ["w1", "w2"], enemy: [ob1]})
ok.("clear_want", A.remove_all_want(rw).attack.want_kills, [])
ok.("clear_killer_empty", A.remove_all_killer(mk.(%{})).attack.killer, [])

# ---------------- competitor ----------------
sc = A.set_competitor(base, ob1)
ok.("set_competitor", A.query_competitor(sc), ob1)

# ---------------- set_default_action ----------------
sd = A.set_default_action(base, "sword", :lunge)
ok.("default_action", A.get_default_action(sd), %{"sword" => :lunge})

# ---------------- action system ----------------
ok.("query_action_nil", A.query_action(base, nil), nil)
sm = A.set_action(base, %{perform: "sword.chan"}, 0)
ok.("set_action_map", A.query_action(sm, nil), %{perform: "sword.chan"})
sf = A.set_action(base, fn s -> 7 end, 0)
ok.("set_action_fun", A.query_action(sf, nil), 7)
ok.("set_action_invalid", A.set_action(base, 42, 0), {:error, "Invalid action"})

# ---------------- select_opponent ----------------
ok.("opp_empty", A.select_opponent(mk.(%{}), %{id: "p"}), nil)
opps = [ob1, ob2]
sop = mk.(%{enemy: opps})
ok.("opp_picked", A.select_opponent(sop, %{id: "p"}) in opps, true)

# ---------------- remove_all_enemy (empty) ----------------
pl = %{id: "p", temp: %{environment_id: "room_a"}}
empty = mk.(%{})
ok.("remove_all_enemy_ok", A.remove_all_enemy(%{attack: empty.attack, player: pl}, pl).attack.enemy, [])

# ---------------- attack (no opponent) ----------------
ok.("attack_no_opp", elem(A.attack(%{attack: empty.attack, player: pl}, pl), 0), :ok)

IO.puts("done")

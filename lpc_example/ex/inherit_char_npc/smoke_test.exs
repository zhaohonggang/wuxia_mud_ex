alias ExKantele.World.Npc.Base, as: N

ok = fn conds ->
  Enum.each(conds, fn {n, a, b} ->
    if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
  end)
end

# accept_fight
ok.([
  {"fight_full_friendly", N.accept_fight(%{qi: 100, max_qi: 100, jing: 100, max_jing: 100}, "friendly"), {0, "我怎么可能会是你的对手？"}},
  {"fight_full_aggr", N.accept_fight(%{qi: 100, max_qi: 100, jing: 100, max_jing: 100}, "aggressive"), {1, "哼！出招吧！"}},
  {"fight_low", N.accept_fight(%{qi: 50, max_qi: 100, jing: 50, max_jing: 100}, "killer"), {0, "今天有些疲惫，改日再战也不迟啊。"}}
])

# accept_hit deterministic rng
rng1 = fn _ -> 1 end
ok.([
  {"hit_aggr_roll1", N.accept_hit(%{qi: 100, max_qi: 100, jing: 100, max_jing: 100}, "aggressive", 3, rng1), {1, "好个家伙，接招！"}}
])
rng100 = fn _ -> 100 end
ok.([
  {"hit_aggr_roll100", N.accept_hit(%{qi: 100, max_qi: 100, jing: 100, max_jing: 100}, "aggressive", 3, rng100), {1, "他奶奶的，怎么这么烦？让我开开杀戒！"}},
  {"hit_low_state", N.accept_hit(%{qi: 40, max_qi: 100, jing: 100, max_jing: 100}, "killer", 1, rng1), {1, "你不仁，我不义！可不要怪我。"}}
])

# accept_kill
ok.([{"kill_aggr", N.accept_kill("aggressive"), {1, "明年的今天，就是你的忌日！"}}])

# heal_decision
ok.([
  {"heal_none_full", N.heal_decision(%{living: true, busy: false, fighting: false, no_exert: false, drugged: false, neili: 200, qi: 100, eff_qi: 100, max_qi: 100, jing: 100, eff_jing: 100, max_jing: 100, max_neili: 200, force_level: 100}), {:none, nil}},
  {"heal_jing", N.heal_decision(%{living: true, busy: false, fighting: false, no_exert: false, drugged: false, neili: 200, qi: 50, eff_qi: 100, max_qi: 100, jing: 70, eff_jing: 100, max_jing: 100, max_neili: 200, force_level: 100}), {:exert, "regenerate"}},
  {"heal_dazuo", N.heal_decision(%{living: true, busy: false, fighting: false, no_exert: false, drugged: false, neili: 100, qi: 40, eff_qi: 100, max_qi: 100, jing: 100, eff_jing: 100, max_jing: 100, max_neili: 200, force_level: 100}), {:dazuo, 20}}
])

# chat_dispatch
ok.([
  {"chat_always", N.chat_dispatch(100, ["hi","yo"], rng1), {:say, "hi"}},
  {"chat_never", N.chat_dispatch(0, ["hi"], rng1), :none},
  {"chat_empty", N.chat_dispatch(100, [], rng1), :none}
])

# check_family
ok.([
  {"fam_match", N.check_family("wudang", nil, "wudang"), true},
  {"fam_born", N.check_family(nil, "kunlun", "kunlun"), true},
  {"fam_no", N.check_family("wudang", nil, "kunlun"), false}
])

# random_move
ok.([
  {"move_first", N.random_move(["north","east"], rng1), "north"},
  {"move_none", N.random_move([], rng1), :none}
])

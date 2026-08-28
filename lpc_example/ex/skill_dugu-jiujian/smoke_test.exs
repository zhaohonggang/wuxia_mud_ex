alias ExKantele.Combat.Skills.DuguJiujian, as: D

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- id / enable / cost ----
ok.("id", D.id(), "dugu-jiujian")
ok.("enable_parry", D.valid_enable("parry"), true)
ok.("enable_sword_lo", D.valid_enable("sword", 20), false)
ok.("enable_sword_hi", D.valid_enable("sword", 30), true)
ok.("enable_sword_def0", D.valid_enable("sword"), false)
ok.("cost", D.practice_cost(), %{qi: 0, neili: 0})

# ---- valid_learn ----
# int too low
ok.("learn_int_low", D.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 38)),
    {:error, "你的天资不足，无法理解独孤九剑的剑意。\n"})
# sword too low
ok.("learn_sword_low",
    D.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"sword" => 50})),
    {:error, "你的基本剑法造诣太浅，无法理解独孤九剑。\n"})
# sword < dugu level
ok.("learn_sword_lt",
    D.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"sword" => 150, "dugu-jiujian" => 200})),
    {:error, "你的基本剑法造诣有限，无法理解更高深的独孤九剑。\n"})
# pass
ok.("learn_ok",
    D.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"sword" => 150, "dugu-jiujian" => 100})),
    :ok)

# ---- query_action: nothing? switches to actions2 ----
first1 = D.query_action(true, 500, fn _ -> 1 end)
ok.("qa_nothing_force", first1["force"], 600)
ok.("qa_nothing_name", first1["skill_name"], nil)          # actions2 have no skill_name
ok.("qa_nothing_nolvl", first1["lvl"], nil)
first0 = D.query_action(false, 500, fn _ -> 1 end)
ok.("qa_normal_force", first0["force"], 290)               # first @actions entry
ok.("qa_normal_noname", first0["skill_name"], nil)
# last element via rng returning length
last0 = D.query_action(false, 500, fn n -> n end)
ok.("qa_normal_last", last0["force"], 410)
last1 = D.query_action(true, 500, fn n -> n end)
ok.("qa_nothing_last", last1["force"], 600)

# ---- query_effect_parry ----
ok.("parry_0", D.query_effect_parry(0), 0)
ok.("parry_89", D.query_effect_parry(89), 0)
ok.("parry_90", D.query_effect_parry(90), 50)
ok.("parry_99", D.query_effect_parry(99), 50)
ok.("parry_100", D.query_effect_parry(100), 55)
ok.("parry_124", D.query_effect_parry(124), 55)
ok.("parry_125", D.query_effect_parry(125), 60)
ok.("parry_150", D.query_effect_parry(150), 65)
ok.("parry_224", D.query_effect_parry(224), 75)
ok.("parry_225", D.query_effect_parry(225), 80)
ok.("parry_249", D.query_effect_parry(249), 80)
ok.("parry_250", D.query_effect_parry(250), 90)
ok.("parry_300", D.query_effect_parry(300), 100)
ok.("parry_349", D.query_effect_parry(349), 110)
ok.("parry_350", D.query_effect_parry(350), 120)

# ---- valid_damage (all branches, deterministic) ----
# branch 1: nothing? + overwhelming dugu -> counter, reduction = -damage
d1 = D.valid_damage(true, 1000, 0, 0, 0, 200)
ok.("vd_nothing_counter", d1[:damage_reduction], -200)
ok.("vd_nothing_msg", is_binary(d1[:msg]), true)
# branch 2: nothing?=false, attacker weak vs defender high -> counter
d2 = D.valid_damage(false, 0, 0, 0, 100, 50)
ok.("vd_weak_counter", d2[:damage_reduction], -50)
# branch 3: nothing falls through -> nil (attacker strong vs defender)
d3 = D.valid_damage(false, 0, 100, 100, 0, 50)
ok.("vd_normal", d3, nil)

IO.puts("done")

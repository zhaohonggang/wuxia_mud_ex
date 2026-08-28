alias ExKantele.Combat.Skills.TaijiQuan, as: T

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- id / enable / cost ----
ok.("id", T.id(), "taiji-quan")
ok.("enable_unarmed", T.valid_enable("unarmed"), true)
ok.("enable_parry", T.valid_enable("parry"), true)
ok.("enable_sword", T.valid_enable("sword"), false)
ok.("cost", T.practice_cost(), %{qi: 35, neili: 59})

# ---- valid_learn ----
# int too low
ok.("learn_int_low", T.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 25)),
    {:error, "你先天悟性太差，难以领会太极拳的要诣。\n"})
# force too low
ok.("learn_force_low",
    T.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"force" => 100, "unarmed" => 150})),
    {:error, "你的内功火候不够，无法学太极拳。\n"})
# unarmed too low
ok.("learn_unarmed_low",
    T.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"force" => 200, "unarmed" => 50})),
    {:error, "你的基本拳脚火候不够，无法学太极拳。\n"})
# unarmed < taiji-quan level
ok.("learn_unarmed_lt",
    T.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"force" => 200, "unarmed" => 150, "taiji-quan" => 200})),
    {:error, "你的基本拳脚水平有限，无法领会更高深的太极拳。\n"})
# pass
ok.("learn_ok",
    T.valid_learn(Kantele.Character.Stats.new() |> Map.put(:int, 40)
      |> Map.put(:skills, %{"force" => 200, "unarmed" => 150, "taiji-quan" => 10})),
    :ok)

# ---- query_action ----
# level >= 350 -> ultimate, bypassing rng/pick_action
ult = T.query_action(350, fn _ -> 1 end)
ok.("qa_ult_lvl", ult["lvl"], 350)
ok.("qa_ult_name", ult["skill_name"], "极意")
ok.("qa_ult_force", ult["force"], nil)   # ultimate has no force key
# low level goes through pick_action; result must have lvl < level
sel = T.query_action(40, fn _ -> 1 end)
ok.("qa_lvl_le", sel["lvl"] < 40, true)
ok.("qa_has_action", is_binary(sel["action"]), true)
# zero level -> first action (lvl 0); level 0 not > 0 so count 0 -> first action
zero = T.query_action(0, fn _ -> 100 end)
ok.("qa_zero_lvl", zero["skill_name"], "揽雀尾")

# ---- valid_combine ----
ok.("combine_wudang", T.valid_combine("wudang-zhang"), true)
ok.("combine_paiyun", T.valid_combine("paiyun-shou"), true)
ok.("combine_other", T.valid_combine("x"), false)

# ---- query_effect_parry ----
ok.("parry_0", T.query_effect_parry(0), 0)
ok.("parry_79", T.query_effect_parry(79), 0)
ok.("parry_80", T.query_effect_parry(80), 50)
ok.("parry_150", T.query_effect_parry(150), 50)
ok.("parry_250", T.query_effect_parry(250), 80)
ok.("parry_300", T.query_effect_parry(300), 100)
ok.("parry_400", T.query_effect_parry(400), 120)

# ---- valid_damage (stub) ----
dmg = T.valid_damage(nil, nil, nil, nil)
ok.("vd_reduction", dmg[:damage_reduction], 50)
ok.("vd_msg", is_binary(dmg[:msg]), true)

IO.puts("done")

alias ExKantele.World.Condition.Poison, as: P

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- init_condition ----
ic = P.init_condition()
ok.("init_name", ic[:name], "poison")
ok.("init_cn", ic[:chinese_name], "Poison")
ok.("init_msg_self", ic[:update_msg_self], "Your ~? poison flares up.")

# ---- mixed_poison nil handling ----
ok.("m_nil_nil", P.mixed_poison(nil, nil), nil)
ok.("m_nil_p2", P.mixed_poison(nil, %{"level" => 5}), %{"level" => 5})
p_only = %{"level" => 7, "remain" => 9}
ok.("m_p1_nil", P.mixed_poison(p_only, nil), p_only)

# ---- merge: same id / same name ----
p1 = %{"level" => 10, "duration" => 0, "remain" => 50, "id" => "a", "name" => "黄昏"}
p2 = %{"level" => 20, "duration" => 0, "remain" => 30, "id" => "a", "name" => "黄昏"}
m_same = P.mixed_poison(p1, p2)
ok.("m_level_max", m_same["level"], 20)
ok.("m_remain_sum", m_same["remain"], 80)
ok.("m_id_same", m_same["id"], "a")
ok.("m_name_same", m_same["name"], "黄昏")

# ---- merge: different ids -> "..."
p3 = %{"level" => 10, "duration" => 0, "remain" => 10, "id" => "a", "name" => "黄昏"}
p4 = %{"level" => 10, "duration" => 0, "remain" => 10, "id" => "b", "name" => "黄昏"}
m_diff = P.mixed_poison(p3, p4)
ok.("m_id_diff", m_diff["id"], "...")
ok.("m_name_same2", m_diff["name"], "黄昏")

# ---- merge: different names -> Deadly Poison if level >= 100
p5 = %{"level" => 100, "duration" => 0, "remain" => 10, "id" => "a", "name" => "黄昏"}
p6 = %{"level" => 110, "duration" => 0, "remain" => 10, "id" => "a", "name" => "夜半"}
m_dp = P.mixed_poison(p5, p6)
ok.("m_deadly", m_dp["name"], "Deadly Poison")
# different names, level < 100 -> "Poison"
p7 = %{"level" => 30, "duration" => 0, "remain" => 10, "id" => "a", "name" => "黄昏"}
p8 = %{"level" => 40, "duration" => 0, "remain" => 10, "id" => "a", "name" => "夜半"}
m_p = P.mixed_poison(p7, p8)
ok.("m_poison", m_p["name"], "Poison")

# ---- merge: default remain when "remain" absent (level * duration)
p9  = %{"level" => 10, "duration" => 5, "id" => "a", "name" => "x"}
p10 = %{"level" => 10, "duration" => 3, "id" => "a", "name" => "x"}
m_r = P.mixed_poison(p9, p10)
ok.("m_remain_default", m_r["remain"], 80)   # 10*5 + 10*3

# ---- merge: one id nil keeps the other ----
p11 = %{"level" => 5, "duration" => 0, "remain" => 5, "id" => nil, "name" => "x"}
p12 = %{"level" => 6, "duration" => 0, "remain" => 6, "id" => "z", "name" => "x"}
m_idnil = P.mixed_poison(p11, p12)
ok.("m_id_p1nil", m_idnil["id"], "z")
m_idnil2 = P.mixed_poison(p12, p11)
ok.("m_id_p2nil", m_idnil2["id"], "z")

# ---- die_reason ----
ok.("die_nil", P.die_reason(nil), "died of poison")
ok.("die_poison", P.die_reason("poison"), "died of poison")
ok.("die_other", P.die_reason("venom"), "venom poison killed")

IO.puts("done")

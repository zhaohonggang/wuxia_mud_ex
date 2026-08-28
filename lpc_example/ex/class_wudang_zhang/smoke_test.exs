alias ExKantele.World.Npc.ClassWudangZhang, as: Z

ok = fn n, a, b ->
  if a == b, do: IO.puts("PASS #{n}"), else: IO.puts("FAIL #{n}: got #{inspect(a)} want #{inspect(b)}")
end

# ---- fixtures ----
# a fully-qualified Wudang disciple of Zhang Sanfeng
disciple = %{
  id: "d", name: "D",
  family: %{name: "武当派", master_id: "zhang_sanfeng"},
  skills: %{"taiji-jian" => 80, "taiji-quan" => 150, "taiji-shengong" => 300, "taoism" => 300, "wudang-xinfa" => 150},
  shen: 200_000, gongxian: 5000, max_neili: 5000, max_jingli: 2000,
  performs: %{}, flags: %{}, int: 45, combat_exp: 600_000
}
non_disciple = %{disciple | family: %{name: "武当派", master_id: "other"}}
not_wudang = %{disciple | family: %{name: "少林派", master_id: "zhang_sanfeng"}}
low_shen = %{disciple | shen: 20_000}

contains = fn str, sub -> String.contains?(str, sub) end

# ---------- handle_ask: dispatch ----------
{uo, ur} = Z.handle_ask(disciple, "foo")
ok.("ask_unknown", {uo, ur}, {:error, :unknown_keyword})
ok.("ask_jian_keyword", elem(Z.handle_ask(disciple, "真武剑"), 0), :ok)
ok.("ask_jiuyang_keyword", elem(Z.handle_ask(%{disciple | flags: %{"can_learn/jiuyang-shengong/wudang" => true, "can_learn/jiuyang-shengong/kunlun" => true, "can_learn/jiuyang-shengong/shaolin" => true}}, "九阳真经"), 0), :ok)
ok.("ask_skill_keyword", elem(Z.handle_ask(disciple, "缠字诀"), 0), :ok)

# ---------- 真武剑 (handle_ask_jian) ----------
{z1, r1} = Z.handle_ask(disciple, "真武剑")
ok.("jian_qualify_type", r1.type, :conditional_give)
ok.("jian_qualify_item", r1.item_id, "zhenwu_jian")
ok.("jian_evil_reject", elem(Z.handle_ask(%{disciple | shen: -100}, "真武剑"), 1).message |> contains.("误入魔道"), true)
ok.("jian_notwudang_reject", elem(Z.handle_ask(not_wudang, "真武剑"), 1).message |> contains.("你打听它干什么"), true)
ok.("jian_nondisciple_reject", elem(Z.handle_ask(non_disciple, "真武剑"), 1).message |> contains.("只有我的弟子"), true)
ok.("jian_lowshen_reject", elem(Z.handle_ask(%{disciple | shen: 1000}, "真武剑"), 1).message |> contains.("行侠仗义"), true)

# ---------- 九阳 (handle_ask_jiuyang) ----------
jy_all = %{disciple | flags: %{"can_learn/jiuyang-shengong/wudang" => true, "can_learn/jiuyang-shengong/kunlun" => true, "can_learn/jiuyang-shengong/shaolin" => true}}
ok.("jy_wudang_ok_info", elem(Z.handle_ask(jy_all, "九阳真经"), 1).type, :info)
ok.("jy_wudang_ok_msg", elem(Z.handle_ask(jy_all, "九阳真经"), 1).message |> contains.("老道已经答应传授"), true)
no_kunlun = %{disciple | flags: %{}}
ok.("jy_nokunlun_reject", elem(Z.handle_ask(no_kunlun, "九阳真经"), 1).message |> contains.("九阳真经"), true)
no_shaolin = %{disciple | flags: %{"can_learn/jiuyang-shengong/kunlun" => true}}
ok.("jy_noshaolin_reject", elem(Z.handle_ask(no_shaolin, "九阳真经"), 1).message |> contains.("追回"), true)
unlock_flags = %{disciple | flags: %{"can_learn/jiuyang-shengong/kunlun" => true, "can_learn/jiuyang-shengong/shaolin" => true}}
{ju, jr} = Z.handle_ask(unlock_flags, "九阳真经")
ok.("jy_unlock_type", jr.type, :unlock)
ok.("jy_unlock_setflag", Enum.any?(jr.effects, &(&1 == %{type: :set_flag, key: "can_learn/jiuyang-shengong/wudang", value: true})), true)

# ---------- 绝招 (handle_ask_skill) ----------
{g1, gr1} = Z.handle_ask(disciple, "缠字诀")
ok.("skill_grant_type", gr1.type, :grant)
ok.("skill_grant_setperform", Enum.any?(gr1.effects, &(&1 == %{type: :set_perform, key: "taiji-jian/chan", value: true})), true)
ok.("skill_notwudang", elem(Z.handle_ask(not_wudang, "缠字诀"), 0) == :error, true)
ok.("skill_already", elem(Z.handle_ask(%{disciple | performs: %{"taiji-jian/chan" => true}}, "缠字诀"), 1) |> contains.("我不是已经教给你了吗"), true)
ok.("skill_lowgongxian", elem(Z.handle_ask(%{disciple | gongxian: 100}, "缠字诀"), 1) |> contains.("效力还不够"), true)
ok.("skill_lowshen", elem(Z.handle_ask(low_shen, "缠字诀"), 1) |> contains.("行侠仗义"), true)
ok.("skill_missing", elem(Z.handle_ask(%{disciple | skills: %{"taiji-jian" => 10}}, "缠字诀"), 1) |> contains.("都没学"), true)

# 太极图 (multi-stage: force_skill extra prereq)
master = %{
  disciple |
  skills: Map.merge(disciple.skills, %{"taiji-quan" => 250, "taiji-shengong" => 300}),
  shen: 300_000, gongxian: 5000
}
{t2, r2} = Z.handle_ask(master, "太极图")
ok.("tu_grant", r2.type, :grant)
ok.("tu_multistage_learned", Enum.any?(r2.effects, &(&1 == %{type: :add_learned_points, delta: 100})), true)
# 太极图 with insufficient 太极神功 (force_skill) -> extra reject
ok.("tu_force_reject", elem(Z.handle_ask(%{master | skills: Map.put(master.skills, "taiji-shengong", 100)}, "太极图"), 1) |> contains.("道学心法"), true)
ok.("skill_lowneili", elem(Z.handle_ask(%{disciple | max_neili: 100}, "鹤嘴劲"), 1) |> contains.("内力修为太浅"), true)
ok.("skill_hezuijin_grant", elem(Z.handle_ask(%{disciple | max_neili: 5000}, "鹤嘴劲"), 1).type, :grant)

# ---------- attempt_apprentice ----------
ok.("apprentice_ok", elem(Z.attempt_apprentice(disciple), 0), :ok)
{aa, ar, amsg} = Z.attempt_apprentice(%{disciple | skills: Map.put(disciple.skills, "wudang-xinfa", 50)})
ok.("apprentice_lowxinfa", {aa, ar, String.contains?(amsg, "多下点功夫")}, {:error, :reject, true})
{ai0, ai1, aim} = Z.attempt_apprentice(%{disciple | int: 20})
ok.("apprentice_lowint", {ai0, ai1, String.contains?(aim, "悟性")}, {:error, :reject, true})
ok.("apprentice_lowshen", Z.attempt_apprentice(%{disciple | shen: 1000}) |> elem(0), :error)
ok.("apprentice_lowexp", Z.attempt_apprentice(%{disciple | combat_exp: 1000}) |> elem(0), :error)

# ---------- accept_object ----------
ok.("obj_other", Z.accept_object(disciple, %{id: "stone"}), {:ok, %{effects: [%{type: :message, text: "你给我这种东西干什么？"}]}})
obj_sword = Z.accept_object(disciple, %{id: "zhenwu_jian", base_id: "zhenwu_jian"}) |> elem(1)
ok.("obj_sword_disciple", Enum.any?(obj_sword.effects, &(&1.type == :destruct_item and &1.item == "zhenwu_jian")), true)
ok.("obj_sword_msg", Enum.any?(obj_sword.effects, &(&1.type == :message and String.contains?(&1.text, "很好"))), true)
obj_sword_nd = Z.accept_object(non_disciple, %{id: "zhenwu_jian", base_id: "zhenwu_jian"}) |> elem(1)
ok.("obj_sword_nd_msg", Enum.any?(obj_sword_nd.effects, &(&1.type == :message and String.contains?(&1.text, "交回"))), true)

# ---------- select_combat_action ----------
ok.("combat_len", length(Z.select_combat_action(disciple, nil, nil)), 13)
ok.("combat_first", hd(Z.select_combat_action(disciple, nil, nil)), {:perform, "sword.chan"})

# ---------- can_learn / try_learn_wudang_jiuyang ----------
ok.("canlearn_yes", Z.can_learn_wudang_jiuyang(%{disciple | flags: %{"can_learn/jiuyang-shengong/wudang" => true}}), true)
ok.("canlearn_no", Z.can_learn_wudang_jiuyang(disciple), false)
ok.("trylearn_nondisciple_err", elem(Z.try_learn_wudang_jiuyang(non_disciple), 0), :error)
ok.("trylearn_disciple_noflag_err", elem(Z.try_learn_wudang_jiuyang(disciple), 0), :error)
learn_good = %{disciple | flags: %{"can_learn/jiuyang-shengong/wudang" => true}, skills: Map.put(disciple.skills, "wudang-jiuyang", 100)}
ok.("trylearn_high_err", {elem(Z.try_learn_wudang_jiuyang(%{learn_good | skills: Map.put(learn_good.skills, "wudang-jiuyang", 200)}), 0), elem(Z.try_learn_wudang_jiuyang(%{learn_good | skills: Map.put(learn_good.skills, "wudang-jiuyang", 200)}), 1) |> contains.("自己研究")}, {:error, true})
ok.("trylearn_evil_err", {elem(Z.try_learn_wudang_jiuyang(%{learn_good | shen: -10}), 0), elem(Z.try_learn_wudang_jiuyang(%{learn_good | shen: -10}), 1) |> contains.("改过自新")}, {:error, true})
ok.("trylearn_ok", Z.try_learn_wudang_jiuyang(learn_good), {:ok, :allowed})

IO.puts("done")

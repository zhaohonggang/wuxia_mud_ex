defmodule Kantele.SectMaster do
  @moduledoc """
  门派师父判定（F3）：纯函数宿主——只做门槛判定链条，不改写任何既有入参形状。

  - 切片 2：纯函数收口，不动宿主调用点。
  - 切片 3：`skills_event.ex teach/2` 已接入 `teachable?/3`（替换原手工
    `Master.prevent_learn?` 门派块，行为等价）；recruit/apprentice/detach/inquiry
    仍按计划后续切片逐个接入。

  宿主形状（已读盘核实，不再臆造）：
    - 师父收徒门槛存 `character.meta.apprentice`（loader `parse_apprentice/1`
      loader.ex:481-510 解析 UCL `apprentice` 段，形状 `%{family:, min_shen:,
      min_exp:, min_skills:, no_recruit:}`；family 为字符串门派名）。
    - 门派信息为 family **map**（`%{name:, master_id:, master_name:, ...}`，
      见 family.ex:5-7、family_event.ex:17 写入形状）；`Family.name/1` 只吃 map，
      字符串会 BadMapError（room.ex:402/2458 同契约）。
    - 师徒/门派判定走 `Family`（`same_family?/2`、`is_apprentice_of?/2`、
      `has_family?/1`）与 `Kantele.Npc.Master`（`prevent_learn?/3`、`attempt_detach/3`）。

  ## teachable?/3
  是否可学某技能：同门派非嫡传被 `Master.prevent_learn?` 拦（对照
  skills_event.ex:43-45）+ 师父已不高于学生等级（对照 skills_event.ex:63-69）。

  ## recruit_gate?/3
  收徒门槛：`meta.apprentice` 的 min_shen/min_exp/min_skills。

  ## detach_penalty?/2
  叛门惩罚判定（对照 master.ex:23 attempt_detach 的同门近似）。
  """

  alias Kantele.Character.Family
  alias Kantele.Character.Stats
  alias Kantele.Npc.Master

  @doc "师父是否能教该技能（host 链：skills_event.ex:38-69）"
  def teachable?(teacher, student, skill) do
    my_family = family_of(teacher)
    student_family = family_of(student)

    cond do
      # LPC `cmds/skill/learn.c:62`：`! me->is_apprentice_of(ob)` 时先调
      # `ob->recognize_apprentice(me, skill)`——参数是**本次请求的技能**，不是固定技能。
      # 该函数分两支，未持本门 mark 一律硬拒（return -1，NPC 已自行 say 过）：
      #   #968 周伯通 zhou.c:151-168：未持 can_learn/zuoyou-hubo/zhou → locked；
      #     已持 mark 但 skill != "zuoyou-hubo" → wrong_skill_deny；
      #   #940 欧阳克 ouyangke.c:354-368：未持 can_learn/lingshe-quan/ke → locked。
      # 已入门弟子（is_apprentice_of）不再走 recognize_apprentice，直接落到下面。
      recognize = recognize_apprentice_reply(teacher, student, skill) ->
        recognize

      # #1022 石清 shiqing.c::recognize_apprentice 是**另一种形状**：不是
      # mark 门，而是「师父名 → 侠义 → 技能白名单 → 技能上限」四道硬门。
      # 顶层 teach.recognize 存在时整段接管（与 no_teach_unlock 的周伯通/欧阳克
      # 形状互斥，二者不会同时配置）。
      recognize = recognize_gate(teacher, student, skill) ->
        recognize

      unlock = no_teach_unlock(teacher, skill) ->
        check_no_teach_unlock(unlock, teacher, student, skill)

      no_teach = no_teach_reason(teacher, skill) ->
        {:error, no_teach}

      # 同门派但非嫡传：Master.prevent_learn? 判定（skills_event.ex:43-45）
      Master.prevent_learn?(my_family, student_family, student_family) ->
        {:error, "你已入别派，老夫不便传授。\n"}

      # 师父已不高于学生（skills_event.ex:63-69）
      not teaches?(teacher, skill) or skill_level(teacher, skill) <= skill_level(student, skill) ->
        {:error, "这一门功夫你已不弱于老夫，没什么可教的了。\n"}

      true ->
        :ok
    end
  end

  # #879 条件 no_teach 解锁判定（对照 miao.c try_to_learn_miaojiajian 等）：
  #   1. 已持 mark（can_learn/<family>/<skill>）→ 已解锁，放行（learned 文案）；
  #   2. combat_exp > min_exp（严格大于）→ 本次解锁，放行并回传 mark 供 host 落盘；
  #   3. 否则 → 硬拒（locked 文案；无则回退通用 no_teach 文案）。
  #
  # #789 武当张三丰「武当九阳功」链式授受（zhang.c try_to_learn_jy）是另一种形状：
  #   - 未持 wudang mark：按是否本弟子分两支逐字拒绝（素不相识 / 弟子也不传）；
  #   - 已持 mark：`wudang-jiuyang > max_skill_level` → maxed_deny；`shen < min_shen` → shen_deny；
  #   - 否则放行（LPC return 0，只正常授艺，learned 文案缺省 nil）。
  # 该形状由 `master_only = true` 触发，禁用 exp 自动解锁（unlock_on_exp = false）。
  defp check_no_teach_unlock(unlock, teacher, student, skill) do
    if Map.get(unlock, :master_only) == true do
      check_jiuyang_unlock(unlock, teacher, student, skill)
    else
      check_mark_exp_unlock(unlock, student, skill)
    end
  end

  # #968 周伯通 / #940 欧阳克 recognize_apprentice：
  # LPC `learn.c` 在「求学者尚未 is_apprentice_of(师父)」时，**无论求教哪门技能**，
  # 都先调 `ob->recognize_apprentice(me, skill)`。该函数按请求的技能决定答复：
  #   - 未持本门 mark（如 `can_learn/zuoyou-hubo/zhou`）→ locked 文案，return -1；
  #   - 已持 mark 但请求的技能 != 本门所限技能（`restricted_skill`）→ wrong_skill_deny；
  #   - 请求的正是所限技能 → return 1（放行，后续 no_teach/等级判定照常）。
  # 因此这里遍历该师父全部 `no_teach_unlock` 条目，而不是只查 skill 自己那一条：
  # 「force」自己没有 unlock 段，但周伯通的 zuoyou-hubo 段管着它。
  # 已入门弟子不再走 recognize_apprentice，故只在非嫡传时判定。
  defp recognize_apprentice_reply(teacher, student, skill) do
    my_family = family_of(teacher)

    if Family.is_apprentice_of?(my_family, family_of(student)) do
      nil
    else
      teach = Map.get(meta_of(teacher), :teach) || %{}
      unlocks = Map.get(teach, :no_teach_unlock) || %{}

      Enum.find_value(unlocks, fn {_key, unlock} ->
        cond do
          not (is_map(unlock) and is_binary(Map.get(unlock, :restricted_skill))) ->
            nil

          not has_mark?(student, Map.get(unlock, :mark)) ->
            nil

          normalize_skill(skill) == normalize_skill(Map.get(unlock, :restricted_skill)) ->
            nil

          true ->
            {:error, Map.get(unlock, :wrong_skill_deny) || "你的武功比我还好，你教我还差不多。"}
        end
      end)
    end
  end

  defp has_mark?(_student, mark) when not is_binary(mark), do: false

  defp has_mark?(student, mark) do
    Map.get(student_marks(student), mark) not in [nil, 0, false]
  end

  # #1022 石清 shiqing.c::recognize_apprentice 四门（LPC 原序）：
  #   1. `ob->query("family/master_name") != "白自在"` → 「素无渊源」；
  #   2. `ob->query("shen") < 10000` → 侠义不足；
  #   3. `skill != "shangqing-jian" && skill != "sword"` → 另投名师；
  #   4. `ob->query_skill(skill, 1) > 179` → 我教不了。
  # 只对**尚未入门**的学生生效；已入门弟子跳过 recognize，直接落到常规授艺链。
  # 返回 nil 表示该段不配置/不命中，继续走后面的 no_teach / 等级判定。
  defp recognize_gate(teacher, student, skill) do
    teach = Map.get(meta_of(teacher), :teach) || %{}

    case Map.get(teach, :recognize) do
      recognize when is_map(recognize) and map_size(recognize) > 0 ->
        if apprentice_of_teacher?(teacher, student) do
          nil
        else
          check_recognize_gate(recognize, student, skill)
        end

      _ ->
        nil
    end
  end

  defp apprentice_of_teacher?(teacher, student) do
    Family.is_apprentice_of?(family_of(teacher), family_of(student))
  end

  defp check_recognize_gate(recognize, student, skill) do
    master_name = Map.get(recognize, :require_master_name)
    # #1044：家族门（无名 family/family_name）、技能下限（空见 buddhism）、
    # 逐技能上限（无名 strike/unarmed >179）均按 LPC 原序插入。
    require_family = Map.get(recognize, :require_family)
    min_skill = Map.get(recognize, :min_skill)
    min_skill_level = Map.get(recognize, :min_skill_level) || 0
    max_levels = Map.get(recognize, :max_skill_levels) || %{}
    maxed_denies = Map.get(recognize, :maxed_denies) || %{}
    min_shen = Map.get(recognize, :min_shen) || 0
    allowed = Map.get(recognize, :allowed_skills) || []
    max_level = Map.get(recognize, :max_skill_level)
    max_skill_cap = Map.get(max_levels, skill_id(skill))

    cond do
      is_binary(master_name) and student_master_name(student) != master_name ->
        {:error, deny_text(recognize, :not_master_deny, "石某与阁下素无渊源，不知阁下这话从何而来？")}

      is_binary(require_family) and student_family_name(student) != require_family ->
        {:error, deny_text(recognize, :family_deny, "阁下与本门素无渊源，不能传授。")}

      is_integer(min_shen) and min_shen > 0 and student_shen(student) < min_shen ->
        {:error,
         deny_text(
           recognize,
           :shen_deny,
           "学武之人，自应以德义为先。你侠义正事做得不够，这招我不能传你。"
         )}

      is_list(allowed) and allowed != [] and skill_id(skill) not in allowed ->
        {:error, deny_text(recognize, :wrong_skill_deny, "阁下的武功，在下实在无从指点，请另投名师吧。")}

      is_binary(min_skill) and min_skill_level > 0 and skill_level(student, skill_id(min_skill)) < min_skill_level ->
        {:error, deny_text(recognize, :min_skill_deny, "你这门功夫火候不足，仍需勤加修习。")}

      is_integer(max_skill_cap) and max_skill_cap > 0 and
          skill_level(student, skill_id(skill)) > max_skill_cap ->
        {:error, per_skill_maxed_text(recognize, maxed_denies, skill)}

      is_integer(max_level) and skill_level(student, skill_id(skill)) > max_level ->
        {:error, deny_text(recognize, :maxed_deny, "这一门功夫你已不弱于在下，没什么可教的了。")}

      true ->
        nil
    end
  end

  # 无名 wuming.c:162-171 的 strike/unarmed 两支独立逐字拒绝；未配置时回退
  # recognize.maxed_deny（石清等旧配置零影响）。
  defp per_skill_maxed_text(recognize, maxed_denies, skill) do
    case Map.get(maxed_denies, skill_id(skill)) do
      text when is_binary(text) and byte_size(text) > 0 ->
        ensure_lf(text)

      _ ->
        deny_text(recognize, :maxed_deny, "这一门功夫你已不弱于在下，没什么可教的了。")
    end
  end

  defp skill_id(skill) when is_binary(skill), do: String.replace(skill, "_", "-")
  defp skill_id(skill) when is_atom(skill), do: skill |> to_string() |> skill_id()

  defp student_shen(character) do
    Map.get(Map.get(meta_of(character), :stats) || %{}, :shen, 0) || 0
  end

  defp check_mark_exp_unlock(unlock, student, skill) do
    mark = Map.get(unlock, :mark)
    min_exp = Map.get(unlock, :min_exp) || 0
    # #日月 任我行「吸星大法」：force > 180 技能阈值解锁（非 combat_exp）。
    min_skills = Map.get(unlock, :min_skills) || %{}
    learned = Map.get(unlock, :learned)
    locked = Map.get(unlock, :locked)

    marks = student_marks(student)
    exp = Map.get(student_stats_of(student), :combat_exp, 0) || 0

    cond do
      is_binary(mark) and Map.get(marks, mark) not in [nil, 0, false] ->
        {:unlock, learned, nil}

      # 未持 mark：只认标记则硬拒（#940 欧阳克 / #968 周伯通 recognize_apprentice），
      # 否则允许 combat_exp 严格大于阈值自动解锁。
      Map.get(unlock, :require_mark_only) == true ->
        {:error, locked || "你此时功力尚浅，此功暂不能传你。\n"}

      # 技能阈值解锁（force > 180）：达标则本次解锁并落 mark。
      map_size(min_skills) > 0 ->
        if meets_min_skills?(student, min_skills) do
          {:unlock, learned, mark}
        else
          {:error, locked || "你此时功力尚浅，此功暂不能传你。\n"}
        end

      is_binary(mark) and exp > min_exp ->
        {:unlock, learned, mark}

      true ->
        {:error, locked || "你此时功力尚浅，此功暂不能传你。\n"}
    end
  end

  # 技能阈值表全部达标（严格大于，复刻 LPC `query_skill(...,1) > N`）。
  defp meets_min_skills?(student, min_skills) when is_map(min_skills) do
    Enum.all?(min_skills, fn {skill_id, need} ->
      skill_level(student, skill_id) > need
    end)
  end

  defp meets_min_skills?(_student, _min_skills), do: true

  # 九阳功：未持 mark 两支逐字拒绝；已持 mark 再判上限/侠义，否则放行。
  defp check_jiuyang_unlock(unlock, teacher, student, skill) do
    mark = Map.get(unlock, :mark)
    marks = student_marks(student)
    has_mark? = is_binary(mark) and Map.get(marks, mark) not in [nil, 0, false]
    max_level = Map.get(unlock, :max_skill_level)
    min_shen = Map.get(unlock, :min_shen)

    cond do
      # 未持 mark：按是否本弟子分两支（LPC try_to_learn_jy 两个 command(say) 分支）
      not has_mark? and Map.get(unlock, :master_only) == true and
          not my_disciple?(teacher, student) ->
        {:error, ensure_lf(Map.get(unlock, :not_master_deny) || jiuyang_not_master_default())}

      not has_mark? ->
        {:error, ensure_lf(Map.get(unlock, :master_deny) || jiuyang_disciple_default())}

      # 已持 mark：武当九阳功力已颇为深厚（>180 自修）
      not is_nil(max_level) and skill_level(student, skill) > max_level ->
        {:error, ensure_lf(Map.get(unlock, :maxed_deny) || jiuyang_maxed_default())}

      # 已持 mark：邪魔外道（shen < 0）
      not is_nil(min_shen) and (Map.get(student_stats_of(student), :shen, 0) || 0) < min_shen ->
        {:error, ensure_lf(Map.get(unlock, :shen_deny) || jiuyang_shen_default())}

      true ->
        {:unlock, Map.get(unlock, :learned), nil}
    end
  end

  defp jiuyang_not_master_default,
    do: "武当九阳神功乃是九阳神功的分支，我少年时得师父觉远大师所授。但阁下与贫道素不相识，怎谈得上“指点”二字？"

  defp jiuyang_disciple_default,
    do: "武当九阳神功乃是九阳神功的分支，我少年时得师父觉远大师所授。虽然这武功在我手里有所改动，但它还是少林的武功，就算是我的弟子也不传授。"

  defp jiuyang_maxed_default, do: "你的武当九阳功力已颇为深厚了，以后你就自己研究吧。"

  defp jiuyang_shen_default,
    do: "老道倒是有心传你九阳功，可是你中邪魔外道如此之深。等你改过自新后再来找老道我吧。"

  # 是否张三丰嫡传：LPC `family/master_id == query("id")`。ex 落 family.master_id =
  # 师父 NPC id（recruit_command 传 conn.character.id），同时兼容按师父名比对。
  defp my_disciple?(teacher, student) do
    teacher_id = Map.get(teacher, :id)
    teacher_name = Map.get(teacher, :name)
    master_id = student_master_id(student)
    master_name = student_master_name(student)

    (is_binary(teacher_id) and teacher_id != "" and master_id == teacher_id) or
      (is_binary(teacher_name) and teacher_name != "" and master_name == teacher_name)
  end

  defp student_master_id(character) do
    case student_family(character) do
      family when is_map(family) ->
        Map.get(family, :master_id) || Map.get(family, "master_id")

      _ ->
        nil
    end
  end

  defp student_marks(%{meta: %{marks: marks}}) when is_map(marks), do: marks
  defp student_marks(%{marks: marks}) when is_map(marks), do: marks
  defp student_marks(_), do: %{}

  defp student_stats_of(%{meta: %{stats: stats}}), do: stats || %{}
  defp student_stats_of(%{stats: stats}), do: stats || %{}
  defp student_stats_of(_), do: %{}

  # #879 读 teach.no_teach_unlock（loader 已按 skill id 归一，连字符键）。
  defp no_teach_unlock(teacher, skill) when is_binary(skill) do
    teach = Map.get(meta_of(teacher), :teach) || %{}

    case Map.get(teach, :no_teach_unlock) || Map.get(teach, "no_teach_unlock") do
      unlocks when is_map(unlocks) and map_size(unlocks) > 0 ->
        unlock =
          Map.get(unlocks, skill) ||
            Map.get(unlocks, String.replace(skill, "_", "-")) ||
            Map.get(unlocks, String.replace(skill, "-", "_"))

        case unlock do
          %{mark: mark} when is_binary(mark) -> unlock
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp no_teach_unlock(_teacher, _skill), do: nil

  @doc """
  收徒门槛（UCL apprentice 段：min_shen/min_exp/min_skills + 性别/permit 门控）

  门控顺序忠实对应 LPC `attempt_apprentice`：
  1. `permit_recruit`（shaolin.h）：detach/betrayer/他派三条；
  2. `gender`（清无/清为/清法）：性别不符分别拒绝（女性/无性文案不同）；
  3. min_shen / max_shen / min_exp / min_skills（既有）。

  `gate` 为 nil 时退化到既有门派行为（无性别/permit 检查），保持向后兼容。

  `gate_order = "lpc_meizhuang"` 按 `meizhuang.h` + 五份 `attempt_apprentice`
  原顺序：permit（日月神教/东方不败弟子例外放行）→ 东方不败弟子 move_party 分支 →
  exp → `any_min_skills`（OR 内功门）→ `recruit_skill_order` 指定的 AND 技能门。
  弟子分支返回 `{:defer, msg, mark}`（不收徒）或 `{:ok_with_mark, warning, mark}`
  （置标记后继续常规门控），由 `FamilyEvent.result/2` 落 `meta.marks`。
  """
  def recruit_gate?(teacher, student, gate \\ nil) do
    config = gate || apprentice_config(teacher)

    min_shen = Map.get(config, :min_shen, 0) || 0
    max_shen = Map.get(config, :max_shen)
    min_exp = Map.get(config, :min_exp, 0) || 0
    min_skills = Map.get(config, :min_skills, %{}) || %{}
    # Task #860：显式顺序优先；老配置缺省 []，行为与原来完全一致。
    recruit_skill_order = Map.get(config, :recruit_skill_order, []) || []
    gender = Map.get(config, :gender)
    permit_recruit = Map.get(config, :permit_recruit) == true
    gate_order = Map.get(config, :gate_order, "permit_first")
    family_name = Map.get(config, :family)
    reject_master_name = Map.get(config, :reject_master_name)

    # #832 镇远镖局王维扬 wangweiyang.c:149：`query_int() < 35 && query_con() < 35`
    # 双低「且」门。LPC query_int/query_con 是派生值（含 tattoo/reborn/技能加成），
    # 故用 Stats.query_int/query_con 而非裸 stats.int/con；未配置时 nil → 跳过，零回归。
    min_int_con_both = Map.get(config, :min_int_con_both)

    # #879 中原苗家 miao.h：`born_family != "中原苗家"` → 不收容外人。
    # 读取 meta.env.born_family（setup_controller.ex:174）；缺 key/空 → 恒不命中。
    required_born_family = Map.get(config, :required_born_family)

    # 绝情谷只要求负神上界，LPC 无「侠义下限」；缺省 0 会误拒全部负神玩家，
    # 故用 UCL 显式 no_min_shen 关闭下界，老配置不变。
    no_min_shen = Map.get(config, :no_min_shen) == true

    shen = Map.get(student_stats(student), :shen, 0) || 0
    exp = Map.get(student_stats(student), :combat_exp, 0) || 0

    # 达摩专用门槛（未配置时全部为 nil → 下面各 cond 分支恒不命中，零回归影响）
    exact_family = Map.get(config, :exact_family) == true
    require_class = Map.get(config, :require_class)
    exact_generation = Map.get(config, :exact_generation)
    min_int = Map.get(config, :min_int)
    hard_min_int = Map.get(config, :hard_min_int)
    max_wpk = Map.get(config, :max_wpk)
    min_max_neili = Map.get(config, :min_max_neili)
    min_per = Map.get(config, :min_per)
    any_min_skills = Map.get(config, :any_min_skills, %{}) || %{}

    # #869 梅庄 meizhuang.h：他派门对日月神教/东方不败弟子放行；
    # attempt_apprentice 首段以 move_party 标记分流（丁坚/两位庄主 return，
    # 黑白子/黄钟公置标记后继续考察）。老配置无这些 key → 全部不命中。
    allow_families = Map.get(config, :allow_families, []) || []
    allow_master_name = Map.get(config, :allow_master_name)
    defer_family = Map.get(config, :defer_family)
    defer_master_name = Map.get(config, :defer_master_name)
    defer_mark = Map.get(config, :defer_mark)
    defer_msg = Map.get(config, :defer_msg)
    defer_continue = Map.get(config, :defer_continue) == true

    defer_hit? =
      is_binary(defer_family) and is_binary(defer_mark) and
        student_family_name(student) == defer_family and
        (is_binary(defer_master_name) and student_master_name(student) == defer_master_name)

    # #804 逍遥派：xiaoyao.h 的 per 门位于 permit_recruit 内部第四条；
    # 无崖子常规收徒顺序为「任一内功≥130 → force/dodge → int → exp」。

    # 达摩 #5：int < 35 —— LPC 在此只 `command("say ...")`、**不 return**。
    # 先记下提示，后续硬门槛照常判定；最终以 {:ok, warning} / {:error, warning <> reason}
    # 交回 FamilyEvent 渲染，保证「先提示悟性不足、再因其它硬门槛被拒」的原版顺序不丢。
    int_warning =
      if not is_nil(min_int) and (student_int(student) || 0) < min_int do
        deny_text(config, :int_deny, "大侠悟性仍有不足，需要进一步锻炼才能领悟更高深的佛法。")
      else
        nil
      end

    promotion_reason = promotion_error(student, config)
    failing_recruit_skill = first_failing_recruit_skill(student, min_skills, recruit_skill_order)

    # Task #644：gate_order 控制 permit_recruit 与 gender 检查先后。
    #   "gender_first"（清无 LPC qing-wu.c）：gender 先于 permit_recruit
    #   "permit_first"（缺省，清为/清法 LPC）：permit_recruit 先于 gender
    result =
      cond do
        # #940 欧阳世家 ouyang.h + ouyangke.c：姓名 → 出身(女性专属文案) → 叛门 → 他派，
        # 顺序与 LPC 逐条 return 一致；仅显式 gate_order="lpc_ouyang" 生效。
        gate_order == "lpc_ouyang" ->
          ouyang_recruit_gate(student, config, exp, family_name)

        # #973 五毒教 wudu.h permit_recruit + 7 位师父 apprentice_gate：
        # 五护法共用 permit_recruit 四门（离教/判师/他派/何铁手旧徒），之后
        # 逐师父的 shen 两档负侠义阶梯（shen_ladder）+ min_exp + min_skills。
        gate_order == "lpc_wudu" ->
          wudu_recruit_gate(student, config, exp, family_name)

        # #986 丐帮 gaibang.h permit_recruit + 10 位可收徒师父
        # （ada/jian/liang 走 deny_all，不进本函数）。门序与 LPC 逐条 return 一致：
        # permit(3) → exp → shen → beggarlvl → force(min_skills) → 属性门 → max_neili。
        gate_order == "lpc_gaibang" ->
          gaibang_recruit_gate(student, config, exp, family_name)

        # #1006 古墓派 yang.c attempt_apprentice：permit(gumu.h 三问) → str →
        # 玉女心经 → max_neili。缺省 permit_first 把 max_neili 放在技能之前且无 str 门，
        # 两门同时失败时文案与 LPC 相反，故独立门序（仅杨过启用，其余三师父走缺省）。
        gate_order == "lpc_gumu_yang" ->
          gumu_yang_recruit_gate(student, config, family_name)

        # #1010 红花会陈家洛 chen.c:129-167：honghua.h permit → shen → combat_exp →
        # honghua-xinfa → max_neili。缺省 permit_first 把 max_neili 放在经验之前，
        # 两门同时失败时文案与 LPC 相反，故独立门序。
        gate_order == "lpc_honghua_chen" ->
          honghua_chen_recruit_gate(student, config, family_name)

        # #1010 红花会余鱼同 yu.c:95-102：先走 honghua.h permit，再无条件拒收。
        # 不能直接用 deny_all（会跳过 permit 三问），故单列门序。
        gate_order == "lpc_honghua_yu" ->
          honghua_yu_recruit_gate(student, config, family_name)

        # 性别门控（清无 gate_order="gender_first" 时置于 permit_recruit 之前，对齐 LPC）
        gate_order == "gender_first" and
          gender not in [nil, ""] and
            student_gender(student) != gender ->
          gender_deny(student, gender, config)

        # permit_recruit（kunlun.h / shaolin.h）三条，顺序与 LPC 一致。
        # #752 昆仑：UCL 可逐句覆写原文；未配置时保持少林缺省，老配置零回归。
        permit_recruit and betrayed_sect?(student, family_name) ->
          {:error, deny_text(config, :betray_sect_deny, "你反反复复，唉！怎么一心向佛？\n")}

        permit_recruit and betrayed_before?(student) ->
          {:error, deny_text(config, :betray_times_deny, "你大逆不道，私自判师，不能容于少林！\n")}

        # #843/#879 duan.h / miao.h / murong.h 的 permit_recruit 顺序：
        # detach/betrayer → betrayer/times → born_family → 他派。放在他派门之前，
        # 才能在「非本家出身且已投他派」时命中 LPC 的出生门文案。
        # 欧阳世家走 lpc_ouyang 专属门序，不受影响；老配置无 required_born_family 恒不命中。
        permit_recruit and is_binary(required_born_family) and
            student_born_family(student) != required_born_family ->
          {:error,
           deny_text(
             config,
             :born_family_deny,
             "我苗家向来便不收容外人。"
           )}

        permit_recruit and other_family?(student, family_name) and
            not other_family_allowed?(student, allow_families, allow_master_name) ->
          {:error,
           deny_text(
             config,
             :other_family_deny,
             "你已经名师指点，为何不下苦功，反而来我们少林寺呢？\n"
           )}

        # #832 镇远镖局王维扬 wangweiyang.c:149-153：permit 之后先判
        # `query_int() < 35 && query_con() < 35`（两项都低才拒，AND），再判 exp / 技能。
        # 仅配置 min_int_con_both 时命中（缺省 nil → 跳过），其它门派零回归。
        is_integer(min_int_con_both) and both_query_attrs_below?(student, min_int_con_both) ->
          {:error,
           deny_text(
             config,
             :int_con_deny,
             "你体质孱弱，为人又不机灵，我收下你有什么用？"
           )}

        # #903 桃花岛 huang.c:205-216：int<25 与 |shen|>10000 均为带 return 的硬门，
        # 位于 permit_recruit 之后、经验/指派分支之前。
        gate_order == "lpc_taohua" and
          not is_nil(hard_min_int) and (student_int(student) || 0) < hard_min_int ->
          {:error, deny_text(config, :int_deny, "我不收资质差的弟子，您请回吧！")}

        # feng/lu/qu 的 UCL 不配 min_shen/max_shen：LPC 三人的 attempt_apprentice
        # 只有 taohua.h permit_recruit + master 标记分支，无侠义门。缺省 min_shen=0
        # 不能误拒负神玩家，故仅当配置显式给出上下界时才进入此门。
        gate_order == "lpc_taohua" and Map.get(config, :taohua_shen_gate) == true and
            (shen < min_shen or
               (is_integer(max_shen) and shen > max_shen)) ->
          {:error, deny_text(config, :shen_deny, "我不与成名人物打交道，您请回吧！")}

        gate_order == "lpc_taohua" ->
          taohua_recruit_gate(student, config, exp, family_name)

        # #789 武当派 wudang.h permit_recruit + 各师父 attempt_apprentice：
        # 9 位师父门控顺序互不相同（zhang/shan/standard/yan/guxu），按 recruit_profile
        # 分派到 wudang_recruit_gate/7，逐字保留 LPC 门槛顺序与拒绝文案。
        gate_order == "lpc_wudang" ->
          wudang_recruit_gate(
            student,
            config,
            exp,
            family_name,
            Map.get(config, :recruit_profile) || "standard",
            Map.get(config, :min_skills, %{}) || %{},
            Map.get(config, :pre_min_skills, %{}) || %{}
          )

        # #951 全真教 quanzhen.h + 22 份 attempt_apprentice：permit 之后各 NPC 门序不同，
        # 用 recruit_profile 分派；内功 OR 门与 AND 技能门分别走 any_min_skills / min_skills。
        gate_order == "lpc_quanzhen" ->
          quanzhen_recruit_gate(
            student,
            config,
            exp,
            family_name,
            Map.get(config, :recruit_profile) || "simple",
            min_skills,
            any_min_skills
          )

        # #804 逍遥派 xiaoyao.h permit_recruit 第四条：`query("per") < 28`。
        # 位置紧随他派门，仍是 permit_recruit 内部，早于各 NPC 自门控。
        not is_nil(min_per) and (student_per(student) || 0) < min_per ->
          {:error, deny_text(config, :per_deny, "大侠的尊容未免次了点，这样可入不了本派！\n")}

        # #869 梅庄 attempt_apprentice 首段：东方不败弟子先写 move_party 标记。
        # 丹青生/丁坚/秃笔翁随后 return（不收徒）；黑白子/黄钟公继续考察。
        defer_hit? and not defer_continue ->
          {:defer, ensure_lf(defer_msg || ""), defer_mark}

        # 梅庄 LPC 把经验门放在「本门内功 OR 门」之前；逍遥无崖子恰好相反。
        gate_order == "lpc_meizhuang" and exp < min_exp ->
          {:error, deny_text(config, :min_exp_deny, "你经验尚浅，武功未成，师父未同意收你为徒。\n")}

        gate_order == "lpc_meizhuang" and any_min_skills_failing?(student, any_min_skills) ->
          {:error,
           deny_text(
             config,
             :any_min_skills_deny,
             "我逍遥派的本门内功的你都没有学利索，还谈什么？\n"
           )}

        # #804 无崖子 wuyazi.c:185-191：逍遥心法/小无相功/北冥神功任一 >= 130。
        # 这是 OR 门（min_skills 是 AND），且位于 force/dodge/int/exp 之前。
        gate_order == "lpc_wuyazi" and any_min_skills_failing?(student, any_min_skills) ->
          {:error,
           deny_text(
             config,
             :any_min_skills_deny,
             "我逍遥派的本门内功的你都没有学利索，还谈什么？\n"
           )}

        gate_order == "lpc_wuyazi" and not is_nil(failing_recruit_skill) ->
          {:error, min_skills_deny(config, failing_recruit_skill)}

        gate_order == "lpc_wuyazi" and
          not is_nil(hard_min_int) and (student_int(student) || 0) < hard_min_int ->
          {:error, deny_text(config, :int_deny, "大侠悟性仍有不足，先回去多读点书吧。\n")}

        gate_order == "lpc_wuyazi" and exp < min_exp ->
          {:error, deny_text(config, :min_exp_deny, "你经验尚浅，武功未成，师父未同意收你为徒。\n")}

        # #804 苏星河 suxingh.c:123-134：先 int30（带 return），再 exp200000。
        gate_order == "lpc_xiaoyao" and
          not is_nil(hard_min_int) and (student_int(student) || 0) < hard_min_int ->
          {:error, deny_text(config, :int_deny, "大侠悟性仍有不足，先回去多读点书吧。\n")}

        # #745 绝情谷 chi.c/zhi.c：若拜师者的师父正是仇家，则拒收。
        # 位置紧随 permit_recruit，之后才是 shen/exp/技能，与 LPC 顺序一致。
        is_binary(reject_master_name) and student_master_name(student) == reject_master_name ->
          {:error,
           deny_text(
             config,
             :reject_master_name_deny,
             "我可不收仇家的徒弟。"
           )}

        # 达摩 attempt_apprentice #2：family_name != 少林派
        exact_family and student_family_name(student) != family_name ->
          {:error, deny_text(config, :family_deny, "大侠与本派素无来往，不知此话从何谈起？")}

        # 达摩 #3：class != bonze
        require_class not in [nil, ""] and student_class(student) != require_class ->
          {:error, deny_text(config, :class_deny, "大侠是俗家弟子，不能在寺内学艺。")}

        # 达摩 #4：generation != 36
        not is_nil(exact_generation) and student_generation(student) != exact_generation ->
          {:error, deny_text(config, :generation_deny, "大侠，贫僧哪里敢当！")}

        # 少林辈分晋升（qing/cheng/hui/dao/xuan/du.h）：generation 分支 +
        # apprentice_ok / luohan_winner / 金刚伏魔圈硬门。未配置 master_generation
        # 的门派完全不受影响。
        not is_nil(promotion_reason) ->
          {:error, promotion_reason}

        # 性别门控（清无/清为/清法；文案对齐 LPC；permit_first 时置于 permit_recruit 之后）
        gate_order == "permit_first" and
          gender not in [nil, ""] and
            student_gender(student) != gender ->
          gender_deny(student, gender, config)

        # 达摩 #6：WPK > 3
        not is_nil(max_wpk) and (student_wpk(student) || 0) > max_wpk ->
          {:error, deny_text(config, :wpk_deny, "大侠杀戮心太重，不适合继续学习武功。")}

        not no_min_shen and shen < min_shen ->
          {:error, deny_text(config, :min_shen_deny, "你的杀气不足，师父未同意收你为徒。\n")}

        not is_nil(max_shen) and shen > max_shen ->
          {:error, deny_text(config, :max_shen_deny, "你心慈手软，杀气不够重，本派不收。\n")}

        not is_nil(min_max_neili) and (student_max_neili(student) || 0) < min_max_neili ->
          {:error, deny_text(config, :max_neili_deny, "你的内力修为不足，师父未同意收你为徒。\n")}

        # #817 玄冥谷 bai.c/lu.c：负神门之后先判冥谷心法/基本掌法，最后才是经验。
        # #933 明教 7 位师父 attempt_apprentice：shen → 圣火心法/附加技能 → exp
        # （技能先于经验，与默认 permit_first 的 exp→skills 相反），与 lpc_xuanming
        # 同构，故共享此「技能先于经验」分支；拒绝文案仍走 min_skills_deny 逐技能覆写。
        gate_order in ["lpc_xuanming", "lpc_mingjiao"] and not is_nil(failing_recruit_skill) ->
          {:error, min_skills_deny(config, failing_recruit_skill)}

        gate_order not in ["lpc_wuyazi", "lpc_xuanming", "lpc_meizhuang", "lpc_mingjiao"] and
            exp < min_exp ->
          {:error, deny_text(config, :min_exp_deny, "你经验尚浅，武功未成，师父未同意收你为徒。\n")}

        # 昆仑何足道 LPC `if (me->query_int() < 38) { ...; return; }` 是硬门，
        # 与达摩 min_int「只提示不拒」不同；二者分开配置，禁止互相复用。
        # 逍遥派两种 gate_order 已在上面按 LPC 顺序提前判定，此处跳过避免文案互换。
        gate_order not in ["lpc_xiaoyao", "lpc_wuyazi"] and
          not is_nil(hard_min_int) and (student_int(student) || 0) < hard_min_int ->
          {:error, deny_text(config, :int_deny, "大侠悟性仍有不足，先回去多读点书吧。\n")}

        # #日月 任我行 ren.c attempt_apprentice 第 5 门：
        # `tianhuan-shenjue < 150 && riyue-xinfa < 150` → 任一达标即过（OR 门）。
        # 缺省 permit_first 路径无 any_min_skills 分支，故按 gate_order 显式补上；
        # 仅 lpc_ren 命中，其它门派零影响。
        gate_order == "lpc_ren" and any_min_skills_failing?(student, any_min_skills) ->
          {:error,
           deny_text(
             config,
             :any_min_skills_deny,
             "你连本门最基本的内功都没修好，怎么学习上乘武学。\n"
           )}

        gate_order != "lpc_wuyazi" and not is_nil(failing_recruit_skill) ->
          {:error, min_skills_deny(config, failing_recruit_skill)}

        gate_order in ["lpc_xuanming", "lpc_mingjiao"] and exp < min_exp ->
          {:error, deny_text(config, :min_exp_deny, "你经验尚浅，武功未成，师父未同意收你为徒。\n")}

        true ->
          :ok
      end

    # #869 黑白子/黄钟公：东方不败弟子先写 move_party 标记，再继续常规门控；
    # 无论最终收徒成功还是被后续门槛拒绝，标记都要落盘。
    result = maybe_with_defer_mark(result, defer_hit?, defer_continue, defer_msg, defer_mark)

    case {int_warning, result} do
      {nil, :ok} ->
        :ok

      {warning, :ok} when is_binary(warning) ->
        {:ok, warning}

      {warning, {:error, reason}} when is_binary(warning) and is_binary(reason) ->
        {:error, warning <> reason}

      {_warning, error} ->
        error
    end
  end

  # UCL 可用 *_deny 覆写 LPC 原文；未配置时用 plan §5.4 登记的缺省文案（含结尾换行）。
  defp deny_text(config, key, default) do
    case Map.get(config, key) do
      text when is_binary(text) and byte_size(text) > 0 -> ensure_lf(text)
      _ -> ensure_lf(default)
    end
  end

  defp ensure_lf(text), do: (String.ends_with?(text, "\n") && text) || text <> "\n"

  # ---- 少林辈分晋升（qing.h / dao.h / hui.h / cheng.h / xuan.h / du.h） ----
  #
  # LPC 的 recruit_apprentice 把学生 generation 设为师父 generation + 1，
  # 所以「越两级」意味着学生带着下一级师尊给的推荐信来拜师。这里逐条复刻：
  #   generation <= 师父        → 贫僧哪里敢当
  #   generation == 师父 + 1    → 直收（cheng/hui/dao 还要求当前法名首字匹配）
  #   generation == 师父 + 2    → apprentice_ok / luohan_winner / 金刚伏魔圈
  # 未配置 master_generation 的普通门派直接 :ok。
  # cond 需要「非错误时返回 nil」而不是 :ok，否则 `{:error, reason} = ...` 会抛 MatchError。
  defp promotion_error(student, config) do
    case promotion_gate(student, config) do
      {:error, reason} when is_binary(reason) -> reason
      _ -> nil
    end
  end

  defp promotion_gate(student, config) do
    case Map.get(config, :master_generation) do
      master_gen when is_integer(master_gen) ->
        generation = student_generation(student) || 0

        cond do
          generation == 0 and Map.get(config, :allow_zero_generation) == true ->
            :ok

          generation <= master_gen ->
            {:error, ensure_lf(Map.get(config, :promotion_deny) || "大侠，贫僧哪里敢当！\n")}

          generation == master_gen + 1 and direct_promotion?(student, config) ->
            :ok

          generation == master_gen + 2 ->
            promotion_by_letter?(student, config)

          true ->
            {:error,
             ensure_lf(
               Map.get(config, :no_letter_deny) ||
                 "大侠，你没有推荐信，不能越级拜师。\n"
             )}
        end

      _ ->
        :ok
    end
  end

  # qing.h 不查法名首字；dao/hui/cheng.h 分别要求 name[0..0] == 清/道/慧。
  defp direct_promotion?(student, config) do
    case Map.get(config, :direct_name_prefix) do
      prefix when is_binary(prefix) and byte_size(prefix) > 0 ->
        String.starts_with?(student_name(student) || "", prefix)

      _ ->
        true
    end
  end

  defp promotion_by_letter?(student, config) do
    cond do
      Map.get(config, :require_apprentice_ok) == true and
          temp_value(student, "apprentice_ok") not in [nil, false, 0, ""] ->
        :ok

      Map.get(config, :allow_luohan_winner) == true and
          env_value(student, "luohan_winner") not in [nil, false, 0, ""] ->
        :ok

      Map.get(config, :require_fumoquan) == true ->
        fumoquan_gate(student, config)

      true ->
        {:error,
         ensure_lf(
           Map.get(config, :no_letter_deny) ||
             "大侠，你没有推荐信，不能越级拜师。\n"
         )}
    end
  end

  # du.h：valid_in_fumoquan == 1 且 dodge/force/parry/buddhism >= 120。
  defp fumoquan_gate(student, config) do
    cond do
      temp_value(student, "valid_in_fumoquan") != 1 ->
        {:error,
         ensure_lf(
           Map.get(config, :no_fumoquan_deny) ||
             "大侠，没能过金刚伏魔圈，我不想收你。\n"
         )}

      not meets_fumoquan_skills?(student, Map.get(config, :fumoquan_min_skills) || 0) ->
        {:error,
         ensure_lf(
           Map.get(config, :fumoquan_skill_deny) ||
             "贫僧要收的是有用之才，你还是回去向你师父学习吧！\n"
         )}

      true ->
        :ok
    end
  end

  defp meets_fumoquan_skills?(student, min_level) when is_integer(min_level) do
    Enum.all?(["dodge", "force", "parry", "buddhism"], fn skill ->
      skill_level(student, skill) >= min_level
    end)
  end

  defp student_name(character) when is_map(character), do: Map.get(character, :name)

  defp temp_value(character, key) when is_map(character) do
    temp = Map.get(meta_of(character), :temp) || %{}
    Map.get(temp, key) || Map.get(temp, String.to_atom(key))
  rescue
    _ -> nil
  end

  defp env_value(character, key) when is_map(character) do
    env = student_env(character)
    Map.get(env, key) || Map.get(env, String.to_atom(key))
  rescue
    _ -> nil
  end

  @doc "LPC shaolin.h permit_recruit：是否叛出/背叛本门（detach/betrayer 门）"
  def betrayed_sect?(student, family_name) when is_binary(family_name) do
    env = student_env(student)

    # LPC query("detach/少林派") / query("betrayer/少林派")：detach/betrayer 是 map，
    # 门名为其中的键（原子或字符串），值为真即叛出过该门。
    flag_set?(Map.get(env, :detach) || Map.get(env, "detach"), family_name) or
      flag_set?(Map.get(env, :betrayer) || Map.get(env, "betrayer"), family_name)
  end

  def betrayed_sect?(_student, _family_name), do: false

  @doc "LPC shaolin.h permit_recruit：betrayer/times 叛师次数非零"
  def betrayed_before?(student) do
    env = student_env(student)
    betrayer = Map.get(env, :betrayer) || Map.get(env, "betrayer")

    times =
      case betrayer do
        %{times: t} -> t
        %{"times" => t} -> t
        t when is_integer(t) -> t
        _ -> 0
      end

    is_integer(times) and times > 0
  end

  # detach/betrayer map 中门名键为真（兼容 atom/string 键，值可为 1/true）。
  # 不创建 atom：遍历现有键比较文本，避免任意门派名污染 atom 表。
  defp flag_set?(map, family_name) when is_map(map) do
    Enum.any?(map, fn {key, value} ->
      key_matches? =
        (is_atom(key) and not is_nil(key) and Atom.to_string(key) == family_name) or
          (is_binary(key) and key == family_name)

      key_matches? and value in [true, 1]
    end)
  end

  defp flag_set?(_, _), do: false

  @doc "LPC shaolin.h permit_recruit：已入他派（family_name 存在且≠本派）"
  def other_family?(student, family_name) when is_binary(family_name) do
    # Family.name/1 只接受 map，nil 会抛 BadMapError（family.ex:33）；
    # 玩家未入门派（family=nil）时 LPC query("family/family_name") 为空 → 不拦。
    case student_family(student) do
      family when is_map(family) and map_size(family) > 0 ->
        case Family.name(family) do
          name when is_binary(name) and name != "" -> name != family_name
          _ -> false
        end

      _ ->
        false
    end
  end

  def other_family?(_student, _family_name), do: false

  # 梅庄 meizhuang.h:17-24：已入日月神教，或师父是东方不败，放行 he family 门。
  defp other_family_allowed?(student, families, master_name) when is_list(families) do
    name = student_family_name(student)

    family_allowed? =
      is_binary(name) and Enum.any?(families, fn allowed -> to_string(allowed) == name end)

    family_allowed? or
      (is_binary(master_name) and student_master_name(student) == master_name)
  end

  defp other_family_allowed?(_student, _families, _master_name), do: false

  # #869 梅庄：东方不败弟子置 move_party 标记后继续常规门控。
  # 把原结果包一层，交给 FamilyEvent 先落标记再收徒/拒绝。
  defp maybe_with_defer_mark(result, hit?, continue?, msg, mark)
       when is_boolean(hit?) and is_boolean(continue?) do
    if hit? and continue? and is_binary(mark) and byte_size(mark) > 0 do
      case result do
        :ok -> {:ok_with_mark, ensure_lf(msg || ""), mark}
        {:ok, warning} -> {:ok_with_mark, warning, mark}
        {:error, reason} -> {:error_with_mark, reason, mark}
        other -> other
      end
    else
      result
    end
  end

  @doc "叛门惩罚判定（同门派叛师=罚，对照 master.ex:23 attempt_detach 同门近似）"
  def detach_penalty?(teacher_family, student_family) do
    if Family.same_family?(teacher_family, student_family) do
      {:penalty, "你欺师灭祖，武功尽失！\n"}
    else
      {:noop}
    end
  end

  @doc """
  问答授绝招判定（UCL `inquiries` 脚本 map；镜像 `class/wudang/yu.c` `ask_me`）。

  `config` 键为字符串（loader `parse_inquiry_value/1` 归一）：
    - `"perform_id"` 授予的绝招 id（如 `"huzhua-shou/juehu"`）
    - `"skill"` 必修技能（等级 < 1 即拒，对应 yu.c「连…都没学」）
    - `"min_levels"` 额外技能门槛 `%{技能 => 等级}`（yu.c 的 force 180 / huzhua-shou 120）
    - `"min_gongxian"` / `"min_shen"` 贡献（400）/ 杀气下限（100000）门槛
    - `"max_shen"` 杀气上限（阴毒门派，如五毒 `shen > -20000` 即拒）
    - `"cost_gongxian"` 授予后扣除的贡献（400）
    - `"min_max_neili"` 内力上限门槛（LPC `query("max_neili") < N` 即拒）；
      玩家侧 `max_neili` 由调用方从 `meta.vitals` 并入 stats map 后传入
    - `"min_dex"` 身法门槛（LPC `query_dex() < N` 即拒，如 hu/hufei.c ask_skill5
      「飞天神行」要求 dex >= 33）；玩家侧 `dex` 取自 `meta.stats.dex`
    - `"max_skill_levels"` 技能上限 map（LPC masterd.c `teach_pfm` 的
      `force` / `dodge` 上界：华山剑宗要求 `query_skill("force") <= 205`，
      超过即拒；loader 会把嵌套键 `_` 归一为 `-`）
    - `"max_neili_cap"` 内力上限的**上界**（LPC
      `me->query("max_neili") > 2000` 即拒；与既有下界 `min_max_neili` 并存）
    - `"level_order"` 有序技能门槛键（星宿派：按 masterd.c 的
      `sk1..sk5 → force → dodge → neili` 逐条判定，避免 map 枚举漂移）
    - `"min_force"` / `"force_deny"`：`masterd.c b["force"]` 独立内功门，
      与 `min_levels["force"]` 并存（夺魂势 sk2=force 130 + force=80）
    - `"min_dodge"` / `"dodge_deny"`：`masterd.c b["dodge"]` 独立轻功门，
      位于 force 之后、neili 之前（蛟龙抱 dodge150 / 如影相随 dodge180）

  各门槛的拒绝文案可用同名 `*_deny` 键覆盖（`maxed` / `family_deny` /
  `skill_deny` / `max_shen_deny` / `gongxian_deny` / `shen_deny` /
  `level_deny` / `max_neili_deny` / `dex_deny` / `force_cap_deny` /
  `force_deny` / `dodge_deny` / `neili_cap_deny` / `perform_deny`），缺省用通用文案。
  门派问询的 LPC 文案每招每NPC 都不同（如血刀门「再罗嗦我宰了你」），
  故按配置回填而不是写死在引擎里。

  同门校验：`player_stats`/`npc_stats` 若带 `:family` 则比较，缺失则不拦（yu.c
  「不是我们武当派的人」分支）。入参可为 `%Stats{}` 或等形 map（跨进程宿主由
  调用方补 `:family`）。

  返回 `{:ok, perform_id, cost}` | `{:error, msg}`；调用方据 `cost` 扣 `gongxian`
  并 `Stats.learn_perform/2`。
  """
  # #745：`gate_order = "lpc_masterd"` 走 LPC masterd.c 原始门控顺序
  # （同门 → 已会 → 神 → 贡献 → 技能存在/等级）；缺省顺序保持既有配置零回归。
  def inquiry_grant(player_stats, npc_stats, config) do
    case Map.get(config, "gate_order") do
      "lpc_masterd" -> inquiry_grant_lpc(player_stats, npc_stats, config)
      "lpc_kunlun" -> inquiry_grant_kunlun(player_stats, npc_stats, config)
      # #845 一灯大师 ask_skill2「先天功乾阳剑气」：已会 → 双门派同门 → 两道技能存在门
      # → 侠义 → force/max_neili → 贡献 → 后天等级链。贡献门在 max_neili 之后，
      # 且同门是「全真教 OR 段氏皇族」，lpc_kunlun 无法表达，故独立门序。
      "lpc_duan_yideng" -> inquiry_grant_duan_yideng(player_stats, npc_stats, config)
      # #835 王维扬 ask_skill6「天刀八势」：已会 → 同门/商家堡双放行 → 商家堡专属拒绝
      # → 技能存在 → 贡献 → 有序等级/内力。两分支文案与 lpc_kunlun 单向同门门不同，
      # 故独立门序；仅该 grant 启用，其它配置零回归。
      "lpc_zhenyuan_tian" -> inquiry_grant_zhenyuan_tian(player_stats, npc_stats, config)
      # #830 陈近南 ask_me：已会 → story/shenzhao 标记 → 侠义 → 凝血神爪存在/等级。
      # 与 lpc_kunlun 的「技能存在 → 侠义」次序不同，且 LPC 无同门/贡献门，
      # 必须独立门序，不能把 story 门塞进昆仑路径而改变既有昆仑配置。
      "lpc_yunlong_chen" -> inquiry_grant_yunlong_chen(player_stats, npc_stats, config)
      "lpc_duan" -> inquiry_grant_duan(player_stats, npc_stats, config)
      "lpc_emei" -> inquiry_grant_emei(player_stats, npc_stats, config)
      "lpc_meizhuang" -> inquiry_grant_meizhuang(player_stats, npc_stats, config)
      "lpc_jiumozhi_fen" -> inquiry_grant_jiumozhi_fen(player_stats, npc_stats, config)
      "lpc_jiumozhi_yan" -> inquiry_grant_jiumozhi_yan(player_stats, npc_stats, config)
      # #931 神龙教洪安通 ask_fei/xian/cui：maxed → family → shen 上界(负) → 技能存在。
      # 缺省路径把 skill 排在 max_shen 之前、lpc_masterd 把 family 排在 maxed 之前，
      # 两者都会与 hong.c 的逐条 return 顺序错位（见 docs/神龙教教学门控移植计划.zh-CN.md §3）。
      "lpc_hong" -> inquiry_grant_hong(player_stats, npc_stats, config)
      # #940 欧阳锋 ask_skill1/2/3：已会 → 同门 → 负 shen 上界 → 贡献 → 杖法等级。
      # 不能用 lpc_kunlun：该门序只认 min_shen，会静默跳过 max_shen 负上界。
      "lpc_ouyang" -> inquiry_grant_ouyang(player_stats, npc_stats, config)
      # #951 全真教 18 条内联 ask_skill*：贡献在侠义之前，且神威浩荡的前置绝招门
      # 位于 max_neili 之后；lpc_kunlun 两处次序都不同，必须独立门序。
      "lpc_quanzhen" -> inquiry_grant_quanzhen(player_stats, npc_stats, config)
      # #日月 任我行 ren.c ask_skill1..5：已会 → 同门 → 技能存在 → 贡献 → 杀气(负上界)
      # → 前置绝招(反璞归真需 zhuo+yu) → 内力 → 内功等级 → 绝招技能等级。
      # 与缺省路径三处不同：贡献在杀气之前、内力在内功之前、两档等级文案分列。
      "lpc_ren" -> inquiry_grant_ren(player_stats, npc_stats, config)
      # #973 五毒教 qiyunao 三绝招 + hetieshou 锁龙诀：已会 → 同门 → 杀气(负上界)
      # → 贡献 → 等级链。与 lpc_ouyang 的差别：杀气在贡献**之前**（ouyang 相反）。
      "lpc_wudu" -> inquiry_grant_wudu(player_stats, npc_stats, config)
      # #986 丐帮绝招：masterd.c teach_pfm 原序 + 洪七公天下无狗的 beggarlvl≥9
      # 与四棒诀前置门（requires_performs，lpc_masterd 路径未消费）。
      "lpc_gaibang" -> inquiry_grant_gaibang(player_stats, npc_stats, config)
      # #1010 红花会 16 条内联 ask_skill*：已会 → 同门 → 技能存在 → 贡献 → 侠义 →
      # 前置绝招 → 有序等级链（dex/max-neili/force/dodge/本招技能各有逐字文案）。
      "lpc_honghua" -> inquiry_grant_honghua(player_stats, npc_stats, config)
      # #795 血刀门宝象/胜谛 ask_skill1：已会 → 同门 → 技能存在 → 贡献 → 杀气(负上界)
      # → 内功等级(force) → 内力(max_neili) → 本招刀法等级。与 lpc_ren 的差别：
      # force 门槛在 max_neili **之前**（LPC baoxiang.c/shengdi.c 的逐条 return 序）；
      # force 与本招等级的文案走 level_deny map（每招两条不同文案）。
      "lpc_xuedao" -> inquiry_grant_xuedao(player_stats, npc_stats, config)
      _ -> inquiry_grant_default(player_stats, npc_stats, config)
    end
  end

  defp inquiry_grant_default(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}
    # #903 桃花岛：书/事件写入的 can_learn 标记门、三选一技能存在门、
    # 以及九阴四招「无同门门」的显式关闭。三者缺省 nil/false/空 map → 老配置零影响。
    required_mark = Map.get(config, "required_mark")
    marks = Map.get(player, :marks) || %{}
    # inquiries 配置不经 loader 的 to_bool/1：UCL 的 `true` 到这里是字符串 "true"。
    # 九阴四招靠 book 标记而非同门门，必须同时接受两种形态。
    skip_family = Map.get(config, "no_family_check") in [true, "true"]
    any_skills = Map.get(config, "any_min_skills", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "这一招你不是已经会了吗？\n")}

      is_binary(required_mark) and Map.get(marks, required_mark) in [nil, 0, false] ->
        {:error, deny(config, "mark_deny", "我与阁下毫无瓜葛，为何有此一问？\n")}

      not skip_family and not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你我并非同门，何来讨教绝招之说？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连#{skill}都没学，还谈什么绝招可言？\n")}

      any_min_skills_failing_stats?(player, any_skills) ->
        {:error, deny(config, "any_min_skills_deny", "你一样功夫都没学，捣什么乱？\n")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny(config, "max_shen_deny", "像你这样心慈手软，就算学了这招也干不了大事！\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny(config, "gongxian_deny", "你为本派效力还不够，这招我先不忙传你。\n")}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny(config, "shen_deny", "这一招太过阴恨，若被你用去我恐怕不放心！\n")}

      # 华山剑宗的 attempt_ask 在调用 MASTER_D->teach_pfm 之前先判「气宗歧途」，
      # 所以这两个上界必须早于 min_levels（否则低技能+高内功会命中错误文案）。
      exceeds_max_levels?(player, config) ->
        {:error, deny(config, "force_cap_deny", "你内功修为已入了旁门，本门绝招不能再传。\n")}

      above_neili_cap?(player, config) ->
        {:error, deny(config, "neili_cap_deny", "你的内力修为太深，本门剑法已不适合你。\n")}

      not meets_levels?(player, min_levels) ->
        {:error, level_deny_text(config, player, min_levels)}

      below_max_neili?(player, config) ->
        {:error, deny(config, "max_neili_deny", "你的内力修为不够，学不成这招。\n")}

      below_min_dex?(player, config) ->
        {:error, deny(config, "dex_deny", "你的身法太差，还需多加练习。\n")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #日月 任我行 ren.c ask_skill1..5 的逐字门序：
  #   1) 已会 (can_perform) → maxed
  #   2) 非同门 (family/family_name) → family_deny
  #   3) 本招技能 < 1 → skill_deny
  #   4) gongxian < min_gongxian → gongxian_deny（贡献在杀气之前）
  #   5) shen > max_shen（负上界，杀气太重反倒拒） → max_shen_deny
  #   6) ask_skill5 专属：can_perform/guzhuo-zhang/zhuo 与 yu 两招须先成 → requires_perform_deny
  #   7) max_neili < min_max_neili → max_neili_deny
  #   8) force < force 门槛 → force_deny
  #   9) 本招技能 < 技能门槛 → skill_level_deny
  defp inquiry_grant_ren(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "这一招我不是已经教过你了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你又不是我日月神教的，跑来捣什么乱？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连本门武功都没学，还谈什么绝招可言？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny(config, "gongxian_deny", "你在教内甚无作为，这招我暂时还不能传你。\n")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny(config, "max_shen_deny", "你这样心慈手软，就算学会这招又有什么用？\n")}

      not requires_performs_known?(player, config) ->
        {:error, deny(config, "requires_perform_deny", "你连前两招都未练成，怎么学这最后一招？\n")}

      below_max_neili?(player, config) ->
        {:error, deny(config, "max_neili_deny", "你的内力太差，怎么修炼上乘武功？\n")}

      below_min_force_level?(player, min_levels) ->
        {:error, deny(config, "force_deny", "你的内功火候尚需提高，练好了再来找我吧。\n")}

      below_min_skill_level?(player, skill, min_levels) ->
        {:error, deny(config, "skill_level_deny", "你的武功还练得不到家，自己下去练练再来吧！\n")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # ask_skill5 需先成 guzhuo-zhang/zhuo 与 yu 两招；单招/缺省一律放行。
  defp requires_performs_known?(player, config) do
    case Map.get(config, "requires_performs") do
      ids when is_list(ids) and ids != [] -> Enum.all?(ids, &perform_known?(player, &1))
      _ -> true
    end
  end

  # #795 血刀门 baoxiang.c/shengdi.c ask_skill1 原序：
  #   已会 → 同门 → 本招技能 < 1 → 贡献 → 杀气(负上界) → 内功等级(force)
  #   → 内力(max_neili) → 本招刀法等级。
  # 与 lpc_ren 的差别：force 门槛在 max_neili 之前；force 与本招等级文案
  # 走 level_deny map（每招两条逐字文案，UCL 已配）。
  defp inquiry_grant_xuedao(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "我不是都已经教过你了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你又不是我血刀门的，再罗嗦我宰了你！\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连本门武功都没学，还罗嗦什么？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny(config, "gongxian_deny", "老祖说了，咋们的绝技不传无功之人。\n")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny(config, "max_shen_deny", "你这样心慈手软，就算学会这招又有什么用？\n")}

      below_min_force_level?(player, min_levels) ->
        {:error, level_deny_for(config, "force", "你的内功修为实在太差，快去多练练再来。\n")}

      below_max_neili?(player, config) ->
        {:error, deny(config, "max_neili_deny", "你的内力差成这样，居然还好意思来找我？\n")}

      below_min_skill_level?(player, skill, min_levels) ->
        {:error, level_deny_for(config, skill, "等你把刀法练熟了再来找我吧。\n")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 血刀 force/本招等级的逐字文案：level_deny 是 map（`force` / `<skill>` 键）；
  # 键缺省时用调用方给的缺省文案（引擎兜底，数据侧已配全）。
  defp level_deny_for(config, key, default) do
    case Map.get(config, "level_deny") do
      denies when is_map(denies) ->
        Map.get(denies, key) || Map.get(denies, to_string(key)) || default

      _ ->
        default
    end
  end

  # LPC `query_skill("force") < N`（min_levels 的 force 键）；缺省不拦。
  # 名字带 `_level` 以区别于 masterd 的 `below_min_force?/2`（读 min_force）。
  defp below_min_force_level?(player, min_levels) do
    case Map.get(min_levels, "force") do
      need when is_integer(need) -> skill_level_of(player, "force") < need
      _ -> false
    end
  end

  # LPC `query_skill(<本招技能>,1) < N`（min_levels 的绝招技能键）；缺省不拦。
  defp below_min_skill_level?(player, skill, min_levels) when is_binary(skill) do
    case Map.get(min_levels, skill) do
      need when is_integer(need) -> skill_level_of(player, skill) < need
      _ -> false
    end
  end

  defp below_min_skill_level?(_player, _skill, _min_levels), do: false

  # LPC masterd.c:76-211 的原始顺序。绝情谷的「神」门槛全为负数（上界），
  # 与贡献/技能门槛同时失败时必须先报杀气文案，不能沿用缺省顺序。
  defp inquiry_grant_lpc(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      # #933 明教 5 条 `free:1` 绝招（张无忌混沌一阳等）：masterd.c teach_pfm
      # 在 free>0 时跳过同门校验。UCL 配置 `no_family_check = true` 表达。
      Map.get(config, "no_family_check") not in [true, "true"] and
          not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你我并非同门，何来讨教绝招之说？\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "这招你不是已经会了么，还缠着我做甚？\n")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny(config, "max_shen_deny", "哼！像你这样的心慈手软之辈，又能干成什么大事？\n")}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny(config, "shen_deny", "你目前所做的侠义正事不够，这招暂时还不能传你。\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny(config, "gongxian_deny", "你为本派作出的贡献不够，这招暂时还不能传你。\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连#{skill}都没学，还谈什么绝招可言？\n")}

      # 星宿派（#811）：LPC masterd.c 的 sk1..sk5 → force → dodge → neili
      # 是固定顺序。配置了 level_order 时走有序链，避免 map 枚举顺序随机
      # 导致「内功不足」与「招式火候不足」互换文案；未配置的老配置保持原路径。
      failing_lpc_level = first_failing_lpc_level(player, config, min_levels) ->
        {:error, ordered_level_deny(config, failing_lpc_level)}

      not meets_named_levels?(player, min_levels) ->
        {:error, level_deny_text(config, player, min_levels)}

      below_min_force?(player, config) ->
        {:error, deny(config, "force_deny", "你目前的内功火候不足，下去练练再来吧。\n")}

      below_min_dodge?(player, config) ->
        {:error, deny(config, "dodge_deny", "你目前的轻功火候不足，下去练练再来吧。\n")}

      above_neili_cap?(player, config) ->
        {:error, deny(config, "neili_cap_deny", "你的内力修为太深，本门剑法已不适合你。\n")}

      below_max_neili?(player, config) ->
        {:error, deny(config, "max_neili_deny", "你的内力修为不够，学不成这招。\n")}

      below_min_dex?(player, config) ->
        {:error, deny(config, "dex_deny", "你的身法太差，还需多加练习。\n")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #986 丐帮绝招：LPC 各师父 ask_skill* 是内联门序，不交 masterd.c。
  # 与缺省路径逐条一致，仅 hong.c ask_skill7「天下无狗」在 shen 之后多两门：
  #   `query("family/beggarlvl") < 9` → 四棒诀前置门 → force/打狗棒法等级。
  # 这两门必须插在技能链之前：若外包在 default 成功之后，低内力会先命中
  # level_deny 文案，与 LPC 返回次序不符。袋数缺省 0（ex 无持久列，见 GAP #996）。
  defp inquiry_grant_gaibang(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_shen = Map.get(config, "min_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}
    min_beggarlvl = Map.get(config, "min_beggarlvl")
    required_mark = Map.get(config, "required_mark")
    marks = Map.get(player, :marks) || %{}
    skip_family = Map.get(config, "no_family_check") in [true, "true"]
    any_skills = Map.get(config, "any_min_skills", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "你这一招我不是已经教过你了吗？\n")}

      is_binary(required_mark) and Map.get(marks, required_mark) in [nil, 0, false] ->
        {:error, deny(config, "mark_deny", "我与阁下毫无瓜葛，为何有此一问？\n")}

      not skip_family and not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你我并非同门，何来讨教绝招之说？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连#{skill}都没学，还谈什么绝招可言？\n")}

      any_min_skills_failing_stats?(player, any_skills) ->
        {:error, deny(config, "any_min_skills_deny", "你一样功夫都没学，捣什么乱？\n")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny(config, "max_shen_deny", "像你这样心慈手软，就算学了这招也干不了大事！\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny(config, "gongxian_deny", "你为本派效力还不够，这招我先不忙传你。\n")}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny(config, "shen_deny", "这一招太过阴恨，若被你用去我恐怕不放心！\n")}

      is_integer(min_beggarlvl) and (Map.get(player, :beggarlvl) || 0) < min_beggarlvl ->
        {:error, deny_lf(config, "beggarlvl_deny", "你在帮中的辈分还不够，等成为长老再说吧。")}

      not requires_performs_known?(player, config) ->
        {:error, deny_lf(config, "requires_perform_deny", "你连前两招都未练成，怎么学这最后一招？")}

      exceeds_max_levels?(player, config) ->
        {:error, deny(config, "force_cap_deny", "你内功修为已入了旁门，本门绝招不能再传。\n")}

      above_neili_cap?(player, config) ->
        {:error, deny(config, "neili_cap_deny", "你的内力修为太深，本门剑法已不适合你。\n")}

      not meets_levels?(player, min_levels) ->
        {:error, level_deny_text(config, player, min_levels)}

      below_max_neili?(player, config) ->
        {:error, deny(config, "max_neili_deny", "你的内力修为不够，学不成这招。\n")}

      below_min_dex?(player, config) ->
        {:error, deny(config, "dex_deny", "你的身法太差，还需多加练习。\n")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #1010 红花会 16 条内联 ask_skill* 的逐条 return 顺序：
  #   1) 已会(can_perform) → 2) 同门（陆菲青同时接受 红花会/武当派）→
  #   3) 本招技能 < 1 → 4) gongxian → 5) shen → 6) 前置绝招（诛天刹神）→
  #   7) level_order 有序门槛（dex / max-neili / force / dodge / 本招技能）。
  # 与缺省路径相比，已会在同门前、技能存在在贡献前、等级链有固定顺序且每档独立文案；
  # 与 lpc_masterd 相比，同门在已会后。所有新键缺省空/nil → 其它配置零影响。
  defp inquiry_grant_honghua(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}

    family_ok? =
      case Map.get(config, "allowed_families") do
        families when is_list(families) and families != [] ->
          Enum.any?(families, &(&1 == Map.get(player, :family)))

        _ ->
          same_family?(player, npc)
      end

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "这招我不是早传授给你了吗？")}

      not family_ok? ->
        {:error, deny(config, "family_deny", "大侠和本会素无瓜葛，何出此言？")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连#{skill}都没学，还谈什么绝招可言？")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny(config, "gongxian_deny", "你在会中所作的贡献还不够，这招我不忙传你。")}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny(config, "shen_deny", "你侠义正事做得不够，这招我不能传你。")}

      not requires_performs_known?(player, config) ->
        {:error,
         deny(
           config,
           "requires_perform_deny",
           "这招是由前招演化而来，等你通晓那招后再来吧。"
         )}

      failing = first_failing_lpc_level(player, config, min_levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 神龙教洪安通 ask_fei/ask_xian/ask_cui 的原始门序（hong.c:170/199/232）：
  #   已会(perform) → 非同门 → shen 上界(负数，`shen > 上界` 即拒) → 主技能存在 → 通过。
  # 与缺省/lpc_masterd 的差别：maxed 在 family 之前、max_shen 在 skill 之前。
  # 文案键 `maxed/family_deny/max_shen_deny/skill_deny` 逐字覆写。
  defp inquiry_grant_hong(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "自己多练练，少在我面前罗嗦！")}

      not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你是哪儿来的？找死啊？")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny(config, "max_shen_deny", "你的手段还不够毒，我可不能传给你绝招！")}

      # hong.c：`query_skill("shedao-qigong",1) < 100/120` —— 即 min_levels 阈值门。
      # （技能不存在=0 也 < 阈值，故无需单独 `skill < 1` 分支。）
      not meets_levels?(player, min_levels) ->
        {:error, deny(config, "skill_deny", "你的蛇岛奇功学好了么？还好意思来问我？")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 欧阳锋 ouyangfeng.c ask_skill1/2/3 的逐条 return 顺序：
  #   已会(can_perform) → 同门(family) → shen 上界(负数) → 贡献 → 灵蛇杖法等级。
  # 例：ask_skill2 是 maxed → family → `shen > -40000` → gongxian≥800 →
  #     `query_skill("lingshe-zhangfa",1) < 120`。缺 max_shen 的左路会被正道玩家绕过。
  defp inquiry_grant_ouyang(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "你还不快去练功去？好好把我们欧阳家发扬光大！\n")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "哪来的野小子敢在这里撒野！\n")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny_lf(config, "shen_deny", "你这人手段不够狠毒，我现在还不能传你绝招！\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你为我欧阳家效力还不够，这招我先不忙传你。\n")}

      failing = first_failing_ordered_level(player, order, min_levels) ->
        {:error, ordered_level_deny(config, failing)}

      not meets_levels?(player, min_levels) ->
        {:error, level_deny_text(config, player, min_levels)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #973 五毒教 qiyunao 三绝招 + hetieshou 锁龙诀：perform nil → 已会 → 同门 →
  # shen 负上界 → 贡献 → level_order/force 链。与 lpc_ouyang 的差别：**杀气在贡献
  # 之前**（ouyang 贡献在杀气前）；锁龙诀 ask_skill3 与其余三绝招的贡献/杀气顺序相反，
  # 故锁龙诀也用本门序。max_shen 为负上界，UCL 逐技能配 shen_deny 原文。
  defp inquiry_grant_wudu(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "你不是已经会了吗？")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "不是我们五毒教的人，何出此言？")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny_lf(config, "shen_deny", "像你这样心慈手软的人是干不成大事的！\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你为我五毒教效力还不够，这招我先不忙传你。\n")}

      failing = first_failing_ordered_level(player, order, min_levels) ->
        {:error, ordered_level_deny(config, failing)}

      not meets_levels?(player, min_levels) ->
        {:error, level_deny_text(config, player, min_levels)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #951 全真教 quanzhen.h + 18 条 ask_skill* 原始门序：
  #   perform nil → 已会 → 同门 → 主技能存在 → 贡献 → 侠义 → level_order → 前置绝招。
  # 与 lpc_kunlun 的差别：贡献/侠义互换，且 requires_perform 在等级链之后。
  defp inquiry_grant_quanzhen(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []
    requires_perform = Map.get(config, "requires_perform")

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "这招我不是已经教会你了吗？")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "阁下与贫道素不相识，不知此话从何说起？")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny_lf(config, "skill_deny", "你连#{skill}都没学，何谈绝招可言？")}

      stat(player, :gongxian) < min_gongxian ->
        {:error,
         deny_lf(
           config,
           "gongxian_deny",
           "你在我全真教内甚无作为，这招我暂时还不能传你。"
         )}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny_lf(config, "shen_deny", "你的侠义正事还做得不够，这招我暂时还不能传你。")}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      not meets_named_levels?(player, levels) ->
        {:error, level_deny_text(config, player, levels)}

      is_binary(requires_perform) and not perform_known?(player, requires_perform) ->
        {:error,
         deny_lf(
           config,
           "requires_perform_deny",
           "此招乃是由「五阴焚灭」升华而来，你还是逐步学习吧？"
         )}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 昆仑 8 NPC 的 ask_skill* 都是内联实现，不经过 MASTER_D->teach_pfm。
  # LPC 顺序固定：已会 → 同门 → 必修技能≥1 → 贡献 → 前置绝招 →
  # level_order 指定的逐条门槛 → 通过。dex / max_neili 以伪技能键进入同一有序链，
  # 否则「内力不足」与「最终技能等级不足」会互换拒绝文案（#752）。
  defp inquiry_grant_kunlun(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []
    requires_perform = Map.get(config, "requires_perform")
    min_perform_skill = Map.get(config, "min_perform_skill")
    # #837 王剑英 ask_skill1/2 的「双技能存在门」：LPC 先判 bagua-zhang < 1
    # 再判 bagua-biao < 1，两句文案不同。缺省空列表时仍走上面单 `skill` 判定，
    # 其它 lpc_kunlun 配置零回归。
    presence_skills = Map.get(config, "presence_skills") || []
    presence_denies = Map.get(config, "presence_deny") || %{}

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "咦？这招你不是已经会了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "和本派素无瓜葛，何出此言？\n")}

      failing_presence = first_missing_presence_skill(player, presence_skills, skill) ->
        {:error, presence_skill_deny_text(config, failing_presence, presence_denies, skill)}

      # 陈近南 ask_me 的侠义（shen）下限：LPC `shen < 1000000` 即拒。
      # 缺省 nil 不拦；`shen_deny` 逐字覆写原文，老配置零影响。
      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny_lf(config, "shen_deny", "你目前所做的侠义正事不够，这招暂时还不能传你。\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error,
         deny_lf(
           config,
           "gongxian_deny",
           "你对本派所作出的贡献不够，这一招我暂时还不能传你。\n"
         )}

      is_binary(requires_perform) and not perform_known?(player, requires_perform) ->
        {:error, deny_lf(config, "requires_perform_deny", "要学此招，必须先通晓「乾坤劲」的奥秘。\n")}

      # 陈近南 ask_me 末条：`query_skill("ningxue-shenzhao", 1) < 250` 即拒。
      # 这里用 min_levels 里该技能的下界作为「未到家」阈值（技能存在门 + 阈值门同字段）；
      # 与 level_order 分开，保证「未到家」文案优先于有序等级链命中。
      is_binary(min_perform_skill) and
          skill_level_of(player, min_perform_skill) <
            (Map.get(levels, min_perform_skill) || 0) ->
        {:error,
         level_deny_text(config, player, %{
           min_perform_skill => Map.get(levels, min_perform_skill)
         })}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #845 一灯大师 yideng.c ask_skill2「先天功乾阳剑气」的内联原序：
  #   已会 → 双门派同门（全真教/段氏皇族）→ yiyang-zhi 存在 → xiantian-gong 存在 →
  #   shen → force → max_neili → gongxian → xiantian-gong/yiyang-zhi/jingluo-xue 等级链。
  # 与 lpc_kunlun 有三处实质差异：同门是 OR、两道技能存在门逐字不同、贡献门夹在
  # max_neili 与后天等级链之间。独立门序且全部新键 opt-in，既有昆仑/段氏配置零影响。
  defp inquiry_grant_duan_yideng(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []
    presence_skills = Map.get(config, "presence_skills") || []
    presence_denies = Map.get(config, "presence_deny") || %{}

    # LPC 的贡献门在 max_neili 之后；level_order 仍保留完整原序，前两项固定为
    # force/max_neili，其余留到贡献门之后，避免把 level_order 拆成两份 UCL 数据。
    pre_gongxian_order = ["force", "max-neili"]
    post_gongxian_order = Enum.reject(order, &(&1 in pre_gongxian_order))

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error,
         deny_lf(
           config,
           "maxed",
           "你先天功的乾阳剑气练到这种境界，老衲已没什么可教的了。\n"
         )}

      not grant_family_allowed?(player, npc, config) ->
        {:error, deny_lf(config, "family_deny", "施主与老衲素不相识，不知施主此话从何说起？\n")}

      failing_presence = first_missing_presence_skill(player, presence_skills, skill) ->
        {:error, presence_skill_deny_text(config, failing_presence, presence_denies, skill)}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny_lf(config, "shen_deny", "你的侠义正事还做得不够，这招老衲暂时还不能传你。\n")}

      failing_pre = first_failing_ordered_level(player, pre_gongxian_order, levels) ->
        {:error, ordered_level_deny(config, failing_pre)}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你的贡献值不够，这招先不忙传你。\n")}

      failing_post = first_failing_ordered_level(player, post_gongxian_order, levels) ->
        {:error, ordered_level_deny(config, failing_post)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # #845 双门派同门门：显式 allowed_families 优先（LPC `family_name != A && != B`），
  # 未配置时回退 same_family?/2，保证新门序被误用也不会凭空放行。
  defp grant_family_allowed?(player, npc, config) do
    case Map.get(config, "allowed_families") do
      families when is_list(families) and families != [] ->
        Enum.any?(families, &(&1 == Map.get(player, :family)))

      _ ->
        same_family?(player, npc)
    end
  end

  # #835 王维扬 wangweiyang.c:412-506 `ask_skill6()`「天刀八势」的原序：
  #   已会 → 同门/商家堡双放行 → 商家堡专属拒绝 → 八卦刀/外八卦/内八卦存在 →
  #   贡献 → 有序等级链（含 max_neili）。
  # 与 lpc_kunlun 唯一实质差别是家庭三分支；其余门完全复用昆仑有序链，
  # 使 UCL 只需为这一招声明 family_exception/family_exception_deny。
  defp inquiry_grant_zhenyuan_tian(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []
    requires_perform = Map.get(config, "requires_perform")
    min_perform_skill = Map.get(config, "min_perform_skill")
    family_error = zhenyuan_tian_family_error(player, npc, config)

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "你不是已经学会了吗？怎么，又给忘记了？\n")}

      is_binary(family_error) ->
        {:error, family_error}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny_lf(config, "skill_deny", "你连这门功夫都没学，还谈什么绝招可言？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error,
         deny_lf(
           config,
           "gongxian_deny",
           "你对本派所作出的贡献不够，这一招我暂时还不能传你。\n"
         )}

      is_binary(requires_perform) and not perform_known?(player, requires_perform) ->
        {:error, deny_lf(config, "requires_perform_deny", "要学此招，必须先通晓「乾坤劲」的奥秘。\n")}

      is_binary(min_perform_skill) and
          skill_level_of(player, min_perform_skill) <
            (Map.get(levels, min_perform_skill) || 0) ->
        {:error,
         level_deny_text(config, player, %{
           min_perform_skill => Map.get(levels, min_perform_skill)
         })}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # LPC ask_skill6 的三条 family 分支（逐字 return）：
  #   1) 同门 → 通过；2) 商家堡 → 先过「非本门」门，再吃专属拒绝；3) 其余 → 素无来往。
  # 缺 player/npc family 时按 LPC `query()` 返回空值处理，落第三分支。
  defp zhenyuan_tian_family_error(player, npc, config) do
    player_family = Map.get(player, :family)
    npc_family = Map.get(npc, :family)
    exception_family = Map.get(config, "family_exception")

    cond do
      is_binary(player_family) and is_binary(npc_family) and player_family == npc_family ->
        nil

      is_binary(exception_family) and player_family == exception_family ->
        deny_lf(
          config,
          "family_exception_deny",
          "你虽然是商家堡的弟子，但没有你师傅同意我也不能传你这招！\n"
        )

      true ->
        deny_lf(config, "family_deny", "大侠和本镖局素无来往，何出此言？\n")
    end
  end

  # #830 陈近南 chen.c:115-142 的 ask_me 内联门序：
  #   已会 → story/shenzhao 标记 → shen < 1000000 → 凝血神爪 < 1 → 凝血神爪 < 250 → 授艺。
  # LPC 无同门、无贡献门，且 story/shen 必须早于技能门；lpc_kunlun 的
  # 「同门 → 技能存在 → shen → 贡献」次序不能复用。缺省 required_mark=nil / min_shen=nil
  # 时对应门不拦，保证其它配置误切到本门序也不会凭空拒绝。
  defp inquiry_grant_yunlong_chen(player_stats, _npc_stats, config) do
    player = normalize_stats(player_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    shen_threshold = Map.get(config, "min_shen")
    required_mark = Map.get(config, "required_mark")
    marks = Map.get(player, :marks) || %{}
    min_perform_skill = Map.get(config, "min_perform_skill")
    levels = Map.get(config, "min_levels", %{}) || %{}
    cost = Map.get(config, "cost_gongxian", 0) || 0

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "你真会开玩笑，会了还来找我。\n")}

      # LPC `if (! me->query("story/shenzhao")) return "你打听这个干嘛？";`
      is_binary(required_mark) and Map.get(marks, required_mark) in [nil, 0, false] ->
        {:error, deny_lf(config, "mark_deny", "你打听这个干嘛？\n")}

      is_integer(shen_threshold) and stat(player, :shen) < shen_threshold ->
        {:error,
         deny_lf(
           config,
           "shen_deny",
           "习武之人最重一个“侠”字，侠义方面你还做得不够！\n"
         )}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny_lf(config, "skill_deny", "你连这门功夫都没学，还谈什么绝招可言？\n")}

      is_binary(min_perform_skill) and
          skill_level_of(player, min_perform_skill) <
            (Map.get(levels, min_perform_skill) || 0) ->
        {:error,
         level_deny_text(config, player, %{
           min_perform_skill => Map.get(levels, min_perform_skill)
         })}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 大理段氏 duanzc/duanzm/yideng/daobf 的 ask_skill* 内联实现：
  # 与 lpc_kunlun 同构，唯一区别是 LPC 先判「贡献(gongxian)」后判「侠义(shen)」
  # （如 duanzm.c ask_skill3：gongxian<400 早于 shen<20000），而昆仑路径相反。
  # 两者拆分而非合并，保证昆仑/天地会既有配置零影响（#619 duan 批）。
  defp inquiry_grant_duan(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "咦？这招你不是已经会了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "和本派素无瓜葛，何出此言？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny_lf(config, "skill_deny", "你连这门功夫都没学，还谈什么绝招可言？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你对本派所作出的贡献不够，这一招我暂时还不能传你。\n")}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny_lf(config, "shen_deny", "你目前所做的侠义正事不够，这招暂时还不能传你。\n")}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 峨眉派 emei.h 内联 ask_skill*（Task #849）：LPC 顺序为
  # 已会 → 同门 → 必修技能≥1 → 贡献 → 等级链 → shen 下限（shen 在最后）。
  # #852 风陵师太 fengling.c ask_skill1/2 在同门之后另有
  # `family/master_id != query("id")` 直传弟子门；用 `require_master_id = true`
  # 逐招开启，未配置的九条灭绝授艺零影响。
  defp inquiry_grant_emei(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    min_shen = Map.get(config, "min_shen")
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []
    require_master_id = Map.get(config, "require_master_id") in [true, "true"]

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "咦？这招你不是已经会了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "和本派素无瓜葛，何出此言？\n")}

      require_master_id and not direct_disciple?(player, npc) ->
        {:error,
         deny_lf(
           config,
           "master_id_deny",
           "只有我的弟子才能学习此招，你还是走吧。\n"
         )}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny_lf(config, "skill_deny", "你连这门功夫都没学，还谈什么绝招可言？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你对本派所作出的贡献不够，这一招我暂时还不能传你。\n")}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      is_integer(min_shen) and stat(player, :shen) < min_shen ->
        {:error, deny_lf(config, "shen_deny", "你目前所做的侠义正事不够，这招暂时还不能传你。\n")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 梅庄五份内联 ask_skill*：已会 → 同门 → 技能存在 → 贡献 → 有序等级链。
  # 与 masterd.c 相反：技能存在门早于贡献，且没有 shen / neili / dex 门。
  defp inquiry_grant_meizhuang(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)

    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "我已经教过你了，自己下去练，别老是跟我纠缠不休。\n")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "大侠和本教素无瓜葛，何出此言？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny_lf(config, "skill_deny", "你连这门功夫都没学，何谈此言？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error,
         deny_lf(
           config,
           "gongxian_deny",
           "你对本庄所作出的贡献不够，这一招我暂时还不能传你。\n"
         )}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  # 天龙寺 jiumozhi.c 两条绝授都是内联实现，且**不查 family**：
  # - ask_me（焚身）：已会 → 火焰刀等级 → shen 上界 → 贡献；
  # - ask_skill（天寰神炎）：已会 → 贡献 → shen 上界 → force → max_neili → 火焰刀。
  # 两条门序不同，拆成独立分支，避免缺省顺序在多门同时失败时互换逐字文案。
  defp inquiry_grant_jiumozhi_fen(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    _npc = normalize_stats(npc_stats)
    perform_id = Map.get(config, "perform_id")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "绝技你已经学会了，剩下的就要靠你自己多练习了。")}

      failing = first_failing_jiumozhi_level(player, order, min_levels) ->
        {:error, ordered_level_deny(config, failing)}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny_lf(config, "max_shen_deny", "你为人太过心软，这招暂时还不能传你。")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你的贡献还不够，这招暂时还不能传你。")}

      true ->
        {:ok, perform_id, cost}
    end
  end

  defp inquiry_grant_jiumozhi_yan(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    _npc = normalize_stats(npc_stats)
    perform_id = Map.get(config, "perform_id")
    cost = Map.get(config, "cost_gongxian", 0) || 0
    min_gongxian = Map.get(config, "min_gongxian", 0) || 0
    max_shen = Map.get(config, "max_shen")
    min_levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "你又来干什么？自己下去多练。")}

      stat(player, :gongxian) < min_gongxian ->
        {:error, deny_lf(config, "gongxian_deny", "你的贡献还不够，这招暂时还不能传你。")}

      is_integer(max_shen) and stat(player, :shen) > max_shen ->
        {:error, deny_lf(config, "max_shen_deny", "你为人太过心软，这招暂时还不能传你。")}

      failing = first_failing_jiumozhi_level(player, order, min_levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  @doc """
  梅庄 `ask_riyue()` 直授技能的纯门控（Task #869）。

  顺序：门派必须为 `"日月神教"` → `can_learn/meizhuang` 标记未置 → 通过。
  成功返回 `{:ok, skill, 10}`，由 `MeizhuangRiyue` handler 写技能/标记、
  处理「高贡献 + 高存款」的额外绝招解锁。
  """
  def riyue_grant(player_stats, config) when is_map(config) do
    player = normalize_stats(player_stats)
    skill = Map.get(config, "skill")
    required_family = Map.get(config, "family")
    mark = Map.get(config, "learn_mark") || "can_learn/meizhuang"
    marks = Map.get(player, :marks) || %{}

    cond do
      not is_binary(skill) ->
        {:error, deny_lf(config, "perform_deny", "这门功夫暂不外传。\n")}

      is_binary(required_family) and Map.get(player, :family) != required_family ->
        {:error, deny_lf(config, "family_deny", "本庄只接待神教人士！\n")}

      Map.get(marks, mark) not in [nil, 0, false] ->
        {:error, deny_lf(config, "maxed", "你不是已经会了吗？还来找我干什么！\n")}

      true ->
        {:ok, skill, config_int(config, "granted_level", 10)}
    end
  end

  def riyue_grant(_player_stats, _config), do: {:error, "这门功夫暂不外传。\n"}

  defp first_failing_ordered_level(player, order, levels)
       when is_list(order) and is_map(levels) do
    Enum.find(order, fn key ->
      value = Map.get(levels, key)

      case value do
        min when is_integer(min) -> named_level_value(player, key) < min
        _ -> false
      end
    end)
  end

  defp first_failing_ordered_level(player, _order, levels) when is_map(levels) do
    Enum.find(levels, fn {key, min} ->
      is_integer(min) and named_level_value(player, key) < min
    end)
    |> case do
      {key, _min} -> key
      _ -> nil
    end
  end

  defp first_failing_ordered_level(_player, _order, _levels), do: nil

  # #837 双技能存在门：presence_skills 为空时退回单一 `skill`，与旧版逐字等价。
  defp first_missing_presence_skill(player, presence_skills, primary_skill) do
    required =
      case presence_skills do
        skills when is_list(skills) and skills != [] -> Enum.map(skills, &normalize_skill/1)
        _ -> if is_binary(primary_skill), do: [normalize_skill(primary_skill)], else: []
      end

    Enum.find(required, fn skill_id -> skill_level_of(player, skill_id) < 1 end)
  end

  # presence_deny 是「技能 id → 逐字未学文案」map；主键走 loader 归一后的连字符，
  # 同时兼容下划线原始键。主技能且未显式配置时仍读 skill_deny，保持旧覆盖语义。
  defp presence_skill_deny_text(config, failing, denies, primary_skill) do
    explicit =
      Map.get(denies, failing) ||
        (is_binary(failing) && Map.get(denies, String.replace(failing, "-", "_")))

    cond do
      is_binary(explicit) ->
        ensure_lf(explicit)

      is_binary(primary_skill) and normalize_skill(primary_skill) == failing ->
        deny_lf(config, "skill_deny", "你连这门功夫都没学，还谈什么绝招可言？\n")

      true ->
        ensure_lf("你连#{failing}都没学，还谈什么绝招可言？\n")
    end
  end

  # 鸠摩智两条绝授的 min_levels 混用真技能与 max_neili 伪键：
  # 显式 level_order 时走有序链；未配置时也必须按命名值取，不能退回
  # `meets_levels?/2` 的纯技能查表（否则 max_neili=5000 会被当成技能 0）。
  defp first_failing_jiumozhi_level(player, order, levels)
       when is_list(order) and order != [] and is_map(levels),
       do: first_failing_ordered_level(player, order, levels)

  defp first_failing_jiumozhi_level(player, _order, levels) when is_map(levels) do
    Enum.find_value(levels, fn {key, min} ->
      if is_integer(min) and named_level_value(player, key) < min, do: key, else: nil
    end)
  end

  defp first_failing_jiumozhi_level(_player, _order, _levels), do: nil

  # UCL 键经 loader 归一：max_neili → "max-neili"，其余技能 id 用连字符。
  defp named_level_value(player, key) when key in ["dex", "dexterity"],
    do: stat(player, :dex)

  defp named_level_value(player, key) when key in ["max-neili", "max_neili"],
    do: stat(player, :max_neili)

  defp named_level_value(player, key), do: skill_level_of(player, key)

  defp ordered_level_deny(config, key) do
    default = "你的修为还不够，练高了再来吧。\n"

    text =
      case Map.get(config, "level_deny") do
        denies when is_map(denies) ->
          Map.get(denies, key) ||
            Map.get(denies, String.replace(key, "-", "_")) ||
            default

        value when is_binary(value) and byte_size(value) > 0 ->
          value

        _ ->
          default
      end

    if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
  end

  # #811：masterd.c 原路径的 level_order 只在显式配置时启用，
  # 未配置时保持绝情谷等老配置的原有 map 遍历行为（零回归）。
  defp first_failing_lpc_level(player, %{"level_order" => order}, levels)
       when is_list(order),
       do: first_failing_ordered_level(player, order, levels)

  defp first_failing_lpc_level(_player, _config, _levels), do: nil

  # LPC masterd.c `b["force"]`：技能门槛 sk1..sk5 之后单独判定的内功等级。
  # 与 min_levels["force"] 并存（夺魂势 sk2=force 130 且 force=80，两条都要保留）。
  defp below_min_force?(player, config) do
    case Map.get(config, "min_force") do
      min when is_integer(min) -> skill_level_of(player, "force") < min
      _ -> false
    end
  end

  # #817 玄冥谷 masterd.c `b["dodge"]`：位于 force 之后、neili 之前。
  defp below_min_dodge?(player, config) do
    case Map.get(config, "min_dodge") do
      min when is_integer(min) -> skill_level_of(player, "dodge") < min
      _ -> false
    end
  end

  # LPC `query_dex() < N`：缺 key 不拦（老配置零影响）。
  # LPC hu/hufei.c ask_skill5 原文：「你的身法太差，还需多加练习。」
  defp below_min_dex?(player, config) do
    case Map.get(config, "min_dex") do
      min when is_integer(min) -> stat(player, :dex) < min
      _ -> false
    end
  end

  @doc """
  问询直授技能（`SectMasterTeachSkill` 的纯门控），对应 LPC 不用
  `MASTER_D->teach_pfm`、直接在 ask 闭包里 `me->set_skill(...)` 的分支。

  `config` 键为字符串（loader `parse_inquiry_value/1` 归一）：
    - `"skill"` 目标技能 id（缺省直接拒绝）
    - `"family"` 限制门派；`"gate_order" = "known_first"` 时「已会」先判
      （令狐冲），否则「同门」先判（成不忧），严格对应两份 LPC 源码顺序
    - `"max_neili_cap"` / `"max_skill_levels"` 上界（剑宗「入了气宗歧途」）
    - `"min_skill_levels"` 下界（剑法 120 / 轻功 180 / 华山剑法 100）
    - `"level_source" = "int"` 时按悟性分档：`int <= pivot ? int : pivot + (int - pivot) * factor`；
      其它值按技能 id 取等级后整除 `"level_divisor"`（冲灵剑法 `lv / 10`）

  拒绝文案键：`maxed` / `family_deny` / `neili_cap_deny` / `max_skill_deny` /
  `min_skill_deny`。返回 `{:ok, skill, level}` | `{:error, msg}`。
  """
  def teach_skill_grant(player_stats, npc_stats, config) do
    player = normalize_stats(player_stats)
    npc = normalize_stats(npc_stats)
    skill = Map.get(config, "skill")
    known_first? = Map.get(config, "gate_order") == "known_first"
    known? = is_binary(skill) and skill_level_of(player, skill) > 0
    same_family? = same_family?(player, npc)

    cond do
      not is_binary(skill) ->
        {:error, deny(config, "perform_deny", "这门功夫暂不外传。\n")}

      known_first? and known? ->
        {:error, deny(config, "maxed", "我该教的都已经教你了。\n")}

      known_first? and not same_family? ->
        {:error, deny(config, "family_deny", "你说什么，我不明白！\n")}

      not known_first? and not same_family? ->
        {:error, deny(config, "family_deny", "你我毫无瓜葛，何出此言？\n")}

      known? ->
        {:error, deny(config, "maxed", "我该教的都已经教你了。\n")}

      above_neili_cap?(player, config) ->
        {:error, deny(config, "neili_cap_deny", "你的内力修为太深，本门功夫已不适合你。\n")}

      exceeds_max_levels?(player, config) ->
        {:error, deny(config, "max_skill_deny", "你的内功修为已入了旁门，不能再学本门剑术。\n")}

      not is_nil(
        failing = first_failing_min_skill(player, Map.get(config, "min_skill_levels", %{}) || %{})
      ) ->
        {:error, min_skill_deny(config, failing)}

      true ->
        {:ok, skill, granted_level(player, config)}
    end
  end

  @doc """
  风清扬 `accept_ask` 的破式解锁纯门控（`SectMasterUnlockPerform`）。

  LPC 顺序：会独孤九剑 → 该式已解锁 → 可用潜能（`potential - learned_points >= 10`）
  → 扣 10 点 `learned_points` → `random(2)` 半数失败 → 授予。失败也扣潜能。

  UCL 键：`perform_id` / `skill` / `min_potential` / `skill_deny` / `maxed` /
  `potential_deny` / `learned`。随机与技能提升由 handler 负责。
  """
  def unlock_perform(player_stats, config) do
    player = normalize_stats(player_stats)
    perform_id = Map.get(config, "perform_id")
    skill = Map.get(config, "skill")
    min_potential = config_int(config, "min_potential", 10)
    potential = Map.get(player, :potential) || 0
    learned_points = Map.get(player, :learned_points) || 0

    cond do
      not is_binary(perform_id) or not is_binary(skill) ->
        {:error, deny(config, "perform_deny", "这门功夫暂不外传。\n")}

      skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你会独孤九剑么？就向我问这个？\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "你不是已经学会这一式了么？\n")}

      potential - learned_points < min_potential ->
        {:exhausted, deny(config, "potential_deny", "你听了教导，颇觉迷茫，看来是潜能不够了。\n")}

      true ->
        {:ok, perform_id, learned_points + min_potential}
    end
  end

  # LPC learn_kuangfeng：`lv = me->query("int")`；
  # `lv <= 30 ? lv : 30 + (lv - 30) * 2`。
  # LPC learn_chongling：`lv = me->query_skill("huashan-jian", 1); set_skill(..., lv/10)`。
  defp granted_level(player, config) do
    case Map.get(config, "level_source") do
      "int" ->
        int = stat(player, :int)
        pivot = config_int(config, "level_pivot", 30)
        factor = config_int(config, "level_factor", 2)

        if int <= pivot do
          int
        else
          pivot + (int - pivot) * factor
        end

      source when is_binary(source) ->
        divisor = config_int(config, "level_divisor", 1)
        level = skill_level_of(player, source)
        if divisor > 0, do: div(level, divisor), else: 0

      _ ->
        0
    end
  end

  defp config_int(config, key, default) do
    case Map.get(config, key) do
      value when is_integer(value) -> value
      _ -> default
    end
  end

  # LPC 每个下界各有独立文案（成不忧：剑法不足 / 轻功不足），故返回首个未达标
  # 技能 id，由 UCL 的 min_skill_deny map 逐项取原文；平坦字符串仍可覆盖全部。
  defp first_failing_min_skill(player, levels) when is_map(levels) do
    case Enum.find(levels, fn {skill, min} -> skill_level_of(player, skill) < min end) do
      {skill, _min} -> skill
      nil -> nil
    end
  end

  defp first_failing_min_skill(_player, _levels), do: nil

  defp min_skill_deny(config, skill) do
    default = "你的基本功夫还不够，练好了再来。\n"

    case Map.get(config, "min_skill_deny") do
      denies when is_map(denies) -> Map.get(denies, skill) || default
      text when is_binary(text) and byte_size(text) > 0 -> text
      _ -> default
    end
  end

  # LPC masterd.c teach_pfm 的 sk1..sk5 下界判定后，华山剑宗额外要求
  # `query_skill("force") <= 205`（成不忧/封不平）。以 map 承载，便于 dodge 等
  # 其它上界沿用；缺 key 不拦（老配置零影响）。
  defp exceeds_max_levels?(player, config) do
    case Map.get(config, "max_skill_levels") do
      levels when is_map(levels) ->
        skills = Map.get(player, :skills) || %{}
        Enum.any?(levels, fn {skill, max} -> (Map.get(skills, skill, 0) || 0) > max end)

      _ ->
        false
    end
  end

  # LPC `me->query("max_neili") > N`：上界；与 `min_max_neili`（下界）并存。
  defp above_neili_cap?(player, config) do
    case Map.get(config, "max_neili_cap") do
      max when is_integer(max) -> (Map.get(player, :max_neili) || 0) > max
      _ -> false
    end
  end

  # 配置覆盖的拒绝文案；缺省走通用文案
  defp deny(config, key, default), do: Map.get(config, key) || default

  # 昆仑 LPC 的 `return "..."` 均由 tell_object 换行渲染；UCL 文案可省略 \n，
  # 这里统一补齐，避免逐条数据重复写转义且保证测试形状一致。
  defp deny_lf(config, key, default) do
    text = deny(config, key, default)

    if is_binary(text) do
      if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
    else
      text
    end
  end

  # `level_deny` 可为整句，也可为逐技能 map（Loader 已把 UCL 下划线键归一为连字符）。
  # 多技能门槛同时不足时取第一个未达标技能，复刻 masterd.c 的逐条 return 顺序。
  defp level_deny_text(config, player, min_levels) do
    fallback = deny(config, "level_deny", "你的修为还不够，练高了再来吧。\n")

    case Map.get(config, "level_deny") do
      denies when is_map(denies) ->
        primary = Map.get(config, "skill")

        # 只把确实存在于 min_levels 的键纳入优先链。否则 `dodge` 这类固定候选
        # 在「本招根本没有 dodge 门槛」时会因 `0 < nil` 被误判为失败项，
        # 使逐技能 level_deny 文案静默退化为缺省（大轮寺破立势实测）。
        # #903 桃花岛：缺省路径也要尊重 level_order 的逐条顺序，否则
        # 「force 与终极招式同时不足」会先报终极招式文案（LPC 顺序相反）。
        configured_order = Map.get(config, "level_order")

        priority_source =
          case configured_order do
            order when is_list(order) and order != [] -> order
            _ -> [primary, "force", "dodge"]
          end

        priority =
          priority_source
          |> Enum.map(fn key ->
            key = if is_binary(key), do: key, else: to_string(key)
            normalized = String.replace(key, "_", "-")
            if Map.has_key?(min_levels, key), do: key, else: normalized
          end)
          |> Enum.reject(fn key -> not Map.has_key?(min_levels, key) end)

        keys = priority ++ (Map.keys(min_levels) -- priority)

        failing =
          Enum.find(keys, fn skill ->
            skill_level_of(player, skill) < Map.get(min_levels, skill)
          end)

        case failing do
          skill when is_binary(skill) ->
            Map.get(denies, skill) || Map.get(denies, String.replace(skill, "_", "-")) ||
              "你的修为还不够，练高了再来吧。\n"

          nil ->
            "你的修为还不够，练高了再来吧。\n"
        end

      _ ->
        fallback
    end
  end

  # LPC `query("max_neili") < N`：缺 key 不拦；玩家侧未并入 max_neili 时按 0 计
  defp below_max_neili?(player, config) do
    case Map.get(config, "min_max_neili") do
      min when is_integer(min) -> stat(player, :max_neili) < min
      _ -> false
    end
  end

  # ---- 内部取数（只读真宿主形状，不臆造） ----
  #
  # 角色 -> family map。真宿主两种落点：
  # - 玩家展开 `meta.family` 是 map（family_event.ex:17）；
  # - NPC（NonPlayerMeta）没有 `:family` 字段，门派身份只在 `meta.teach.family`
  #   （loader.parse_teach 的字符串门派名，skills_event.ex:38-39 同源读法）。
  #   这里按 host 顺序：先 meta.family map，缺失则用 teach.family 合成 %{name:}，
  #   保证 teach/2 侧面同门派非嫡传判定与 host 一致。
  defp family_of(%{meta: meta} = character) when is_map(meta) do
    case Map.get(meta, :family) do
      family when is_map(family) and map_size(family) > 0 ->
        family

      _ ->
        teach_family(character, meta)
    end
  end

  # 直接给 family map（不包 meta 壳，如 build_conn 侧传 student_family map）
  defp family_of(family) when is_map(family), do: family
  defp family_of(_), do: %{}

  # teach.family 合成（host 同源：skills_event.ex:39）
  defp teach_family(_character, meta) do
    case Map.get(Map.get(meta, :teach) || %{}, :family) do
      nil -> %{}
      name -> %{name: name}
    end
  end

  # 角色 -> meta 壳
  defp meta_of(character) when is_map(character), do: Map.get(character, :meta) || %{}
  defp meta_of(_), do: %{}

  defp student_stats(character) do
    stats = Map.get(meta_of(character), :stats) || %{}
    %{shen: Map.get(stats, :shen, 0) || 0, combat_exp: Map.get(stats, :combat_exp, 0) || 0}
  end

  # 角色当前内力上限，取自 meta.vitals.max_neili（LPC query("max_neili") 落库位置，见 records.ex）。
  # 缺 key 时按 0 计，配置缺省时不拦截。
  defp student_max_neili(character) do
    vitals = Map.get(meta_of(character), :vitals) || %{}
    Map.get(vitals, :max_neili) || 0
  end

  defp apprentice_config(character), do: Map.get(meta_of(character), :apprentice) || %{}

  # 性别取自 meta.env（LPC query("gender") 落库位置，见 records.ex:33-35）；
  # atom/string 双读，缺省 "男性" 与 LPC 一致。
  defp student_gender(character) do
    env = student_env(character)
    Map.get(env, :gender) || Map.get(env, "gender") || "男性"
  end

  # 性别拒绝文案对齐 LPC：
  # - 清无/清为：女性「女施主呀，贫僧可不敢开这等玩笑啊」/ 无性「这位公公…」
  # - 清法 ask_for_join：女性「可去后山庵里受戒」/ 无性「回去伺候皇上」
  # 此处是拜师(attempt_apprentice)门控，用清无/清为文案。
  # 性别拒绝文案：UCL `gender_deny` 可覆写（华山岳不群「我不收女徒弟…」、
  # 岳夫人「这位…你还是找我师哥去吧」）；未配置时回退少林既有文案。
  defp gender_deny(character, _required, config) do
    case Map.get(config, :gender_deny) do
      text when is_binary(text) and byte_size(text) > 0 -> {:error, ensure_lf(text)}
      _ -> gender_deny(character)
    end
  end

  defp gender_deny(character) do
    case student_gender(character) do
      "女性" -> {:error, "阿弥陀佛！女施主呀，贫僧可不敢开这等玩笑啊。\n"}
      "无性" -> {:error, "阿弥陀佛！这位公公，你还是回去伺候皇上吧。\n"}
      _ -> {:error, "阿弥陀佛！施主恕难从命。\n"}
    end
  end

  defp student_env(character), do: Map.get(meta_of(character), :env) || %{}
  defp student_family(character), do: Map.get(meta_of(character), :family)

  # #879 中原苗家 miao.h：`ob->query("born_family")` 读取玩家出身家族。
  # ex 落库于 meta.env.born_family（setup_controller.ex:174 put_character_env），
  # atom/string 双读；缺 meta（纯 stats 测试宿主）→ nil，不触发门控。
  defp student_born_family(character) do
    env = student_env(character)
    Map.get(env, :born_family) || Map.get(env, "born_family")
  end

  # #745 绝情谷 `me->query("family/master_name")`：family 是 map，atom/string 双读；
  # 角色缺 meta（纯 stats 测试宿主）时返回 nil，不触发门控。
  defp student_master_name(character) do
    case student_family(character) do
      family when is_map(family) and map_size(family) > 0 ->
        Map.get(family, :master_name) || Map.get(family, "master_name")

      _ ->
        nil
    end
  end

  # 达摩门控读取（LPC ob_fam["family_name"] / query("class") / ob_fam["generation"] /
  # query_int() / query("WPK")）。WPK 在 ex 无独立列，与 PKS/MKS 同属 meta.combat
  # 统计映射，并兼容 env（LPC set() 仓库）；二者都没有时按 0 处理。
  defp student_family_name(character) do
    case student_family(character) do
      family when is_map(family) and map_size(family) > 0 ->
        case Family.name(family) do
          name when is_binary(name) -> name
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp student_class(character) do
    case student_family(character) do
      family when is_map(family) -> Map.get(family, :class)
      _ -> nil
    end
  end

  defp student_generation(character) do
    case student_family(character) do
      family when is_map(family) -> Map.get(family, :generation)
      _ -> nil
    end
  end

  # #940 欧阳世家 `kungfu/class/ouyang/{ouyang.h,ouyangfeng.c,ouyangke.c}`。
  # ouyang.h permit_recruit 四条按 LPC 原序：姓名 → 出身 → 叛门 → 他派；
  # ouyangke.c 在 permit_recruit 之前还有「女性外姓」专属拒绝。
  defp ouyang_recruit_gate(student, config, exp, family_name) do
    names = Map.get(config, :reject_student_names, []) || []
    born = Map.get(config, :required_born_family)
    name = student_name(student)
    student_born = student_born_family(student)
    gender = Map.get(config, :gender)

    cond do
      is_list(names) and is_binary(name) and name in names ->
        {:error,
         deny_text(
           config,
           :reject_student_name_deny,
           "大怒：他奶奶的！你起这个名字是什么意思啊？"
         )}

      is_binary(born) and student_born != born ->
        deny =
          if student_gender(student) == "女性" and Map.get(config, :female_born_family_deny) do
            deny_text(config, :female_born_family_deny, "你不是我们欧阳家的人，我怎能收你为徒？")
          else
            deny_text(config, :born_family_deny, "你不是我们欧阳家的人，我怎能收你为徒？")
          end

        {:error, deny}

      betrayed_sect?(student, family_name) ->
        {:error, deny_text(config, :betray_sect_deny, "你反复无常，我不能收你为徒！")}

      betrayed_before?(student) ->
        {:error, deny_text(config, :betray_times_deny, "你反复无常，我不能收你为徒！")}

      other_family?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :other_family_deny,
           "你虽然是我们欧阳家的人，但你入了其他门派，我不能收你为徒！"
         )}

      is_binary(gender) and student_gender(student) != gender ->
        gender_deny(student, gender, config)

      exp < (Map.get(config, :min_exp) || 0) ->
        {:error,
         deny_text(
           config,
           :min_exp_deny,
           "你的经验还不够，先和我的侄儿欧阳克学习武功吧。"
         )}

      true ->
        {:ok, deny_text(config, :accept_msg, "好... 很好！")}
    end
  end

  # #973 五毒教 `kungfu/class/wudu/wudu.h` permit_recruit 四门 + 逐师父 apprentice_gate。
  # 五护法/长老/教主共用 wudu.h 前三条（离教 → 判师 → 他派）；第四条 `master_name ==
  # "何铁手"`（sneer + 拒绝）逐师父不同。之后走 shen_ladder 负侠义阶梯 → min_exp →
  # min_skills（wudu-xinfa / wudu-qishu）。仅显式 gate_order="lpc_wudu" 命中。
  defp wudu_recruit_gate(student, config, exp, family_name) do
    reject_master = Map.get(config, :reject_master_name)

    cond do
      betrayed_sect?(student, family_name) ->
        {:error, deny_text(config, :betray_sect_deny, "你既然已经离教，就别再回来！")}

      betrayed_before?(student) ->
        {:error, deny_text(config, :betray_times_deny, "判师之徒，哼！小心我把你千刀万剐！")}

      other_family?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :other_family_deny,
           "你不是已经有了师傅么，还来干什么？做卧底么？"
         )}

      is_binary(reject_master) and student_master_name(student) == reject_master ->
        # LPC 此处先 sneer emote 再 say；ex 仅 say（NPC emote 通道 GAP 已登记 §5）。
        {:error, deny_text(config, :reject_master_name_deny, "既然你已经跟随了那个贱人，却又来找我作甚？")}

      failing = first_failing_shen_ladder(student, config) ->
        {:error, failing}

      exp < (Map.get(config, :min_exp) || 0) ->
        {:error, deny_text(config, :min_exp_deny, "先去增长点经验吧。")}

      failing_skill =
          first_failing_recruit_skill(
            student,
            Map.get(config, :min_skills, %{}) || %{},
            Map.get(config, :recruit_skill_order, []) || []
          ) ->
        {:error, min_skills_deny(config, failing_skill)}

      true ->
        {:ok, deny_text(config, :accept_msg, "不错，不错。")}
    end
  end

  # shen_ladder 逐档消费：数组对象 `[{max=负上界, deny=逐字文案}, ...]`。
  # LPC `if (shen > N) deny` → 返回首个 `shen > rung.max` 的 rung.deny；全过（shen 很负）
  # → nil，继续后续 min_exp/min_skills。缺省空列表不拦（老配置零影响）。
  defp first_failing_shen_ladder(student, config) do
    ladder = Map.get(config, :shen_ladder, []) || []
    shen = Map.get(student_stats(student), :shen, 0) || 0

    case Enum.find(ladder, fn rung -> is_integer(rung.max) and shen > rung.max end) do
      %{deny: text} when is_binary(text) and byte_size(text) > 0 -> ensure_lf(text)
      %{deny: text} -> text
      _ -> nil
    end
  end

  # #986 丐帮 `kungfu/class/gaibang/gaibang.h` permit_recruit 三条 + 10 位可收徒师父
  # 的 attempt_apprentice 逐条门序（ada/jian/liang 无条件拒收，走 npc_shop_event 的
  # deny_all，不进入本函数）。LPC 原序：
  #   permit(离帮/叛师/他派) → combat_exp → shen → beggarlvl → force → 属性 → max_neili
  # 与缺省 `permit_first` 的 `permit→shen→exp→skills` 不同（exp/shen 互换且有袋数/属性门），
  # 故独立门序。所有新增字段缺省 nil → 对应门跳过，其它门派零影响。
  defp gaibang_recruit_gate(student, config, exp, family_name) do
    shen = Map.get(student_stats(student), :shen, 0) || 0
    no_min_shen = Map.get(config, :no_min_shen) == true
    min_shen = Map.get(config, :min_shen, 0) || 0
    min_exp = Map.get(config, :min_exp, 0) || 0
    min_skills = Map.get(config, :min_skills, %{}) || %{}
    skill_order = Map.get(config, :recruit_skill_order, []) || []
    accept = deny_text(config, :accept_msg, "好吧，你以后就跟着我吧。")

    cond do
      # gaibang.h 三条，顺序与 LPC 逐条 return 一致（缺省文案对齐原文）。
      betrayed_sect?(student, family_name) ->
        {:error, deny_text(config, :betray_sect_deny, "嘿嘿，你当初走的时候是怎么说的？")}

      betrayed_before?(student) ->
        {:error, deny_text(config, :betray_times_deny, "我们丐帮行事堂堂正正，绝不接纳判师之徒。")}

      other_family?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :other_family_deny,
           "你既然已经有了名师指点，还来我们丐帮干什么？"
         )}

      exp < min_exp ->
        {:error, deny_text(config, :min_exp_deny, "你的江湖经验不够，还是先向各位长老学习吧。")}

      not no_min_shen and shen < min_shen ->
        {:error, deny_text(config, :min_shen_deny, "你身为丐帮弟子，竟然不做好事？")}

      failing = gaibang_beggarlvl_gate(student, config) ->
        {:error, failing}

      failing_skill = first_failing_recruit_skill(student, min_skills, skill_order) ->
        {:error, min_skills_deny(config, failing_skill)}

      failing = gaibang_attribute_gate(student, config) ->
        {:error, failing}

      not is_nil(Map.get(config, :min_max_neili)) and
          (student_max_neili(student) || 0) < Map.get(config, :min_max_neili) ->
        {:error, deny_text(config, :max_neili_deny, "就你那点内力哪里学得了什么上乘武功？")}

      true ->
        {:ok, accept}
    end
  end

  # LPC `query("family/beggarlvl") < N`（丐帮袋数）。ex 玩家 family map 里
  # beggarlvl 目前无持久列，测试/后续落地走 meta.env.beggarlvl（atom/string 双读）。
  # 未配置 min_beggarlvl 或玩家无该 key → nil，不拦（老配置零影响）。
  defp gaibang_beggarlvl_gate(student, config) do
    case Map.get(config, :min_beggarlvl) do
      need when is_integer(need) ->
        if student_beggarlvl(student) < need do
          deny_text(config, :beggarlvl_deny, "你在本帮的地位太低，还是先向其他师父学习吧。")
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp student_beggarlvl(character) do
    env = student_env(character)

    case Map.get(env, :beggarlvl) || Map.get(env, "beggarlvl") do
      lvl when is_integer(lvl) -> lvl
      _ -> 0
    end
  end

  # 两类属性门（互斥，同一 NPC 只配其一）：
  #   min_str         — 马大元 query_str() < 26（硬拒）
  #   min_any_attribute — 洪七公 str<40 && int<40 && con<40 && dex<40 才拒（OR 门）
  defp gaibang_attribute_gate(student, config) do
    cond do
      is_integer(Map.get(config, :min_str)) and
          student_attr(student, :str) < Map.get(config, :min_str) ->
        deny_text(config, :str_deny, "我的武艺以刚猛为主，你膂力不行，还是算了吧。")

      is_integer(Map.get(config, :min_any_attribute)) and
          Enum.all?([:str, :int, :con, :dex], fn attr ->
            student_attr(student, attr) < Map.get(config, :min_any_attribute)
          end) ->
        deny_text(
          config,
          :any_attribute_deny,
          "我说你这人体格也不行，脑筋也不灵光，还能和我学什么？"
        )

      true ->
        nil
    end
  end

  defp student_attr(character, attr) do
    Map.get(Map.get(meta_of(character), :stats) || %{}, attr, 0) || 0
  end

  # #1006 古墓派 yang.c attempt_apprentice（LPC 原序逐条 return）：
  #   gumu.h permit(离派/判师/他派) → str < 45 → yunv-xinjing < 120 → max_neili < 2000 → 收徒。
  # 缺省 permit_first 把 max_neili 判在技能之前、且完全没有 str 门；两门同时失败时
  # 文案顺序与 LPC 相反，故为杨过独立门序。字段缺省 nil → 对应门跳过，其它门派零影响。
  defp gumu_yang_recruit_gate(student, config, family_name) do
    min_str = Map.get(config, :min_str)
    min_skills = Map.get(config, :min_skills, %{}) || %{}
    skill_order = Map.get(config, :recruit_skill_order, []) || []
    min_max_neili = Map.get(config, :min_max_neili)
    accept = deny_text(config, :accept_msg, "好吧，看你资质尚可，我就收下你这个徒弟了。\n")

    cond do
      # gumu.h 三条，缺省文案对齐 LPC 原文（UCL 可逐句覆写）。
      betrayed_sect?(student, family_name) ->
        {:error, deny_text(config, :betray_sect_deny, "唉！去便去了，回来又是何苦由来？")}

      betrayed_before?(student) ->
        {:error, deny_text(config, :betray_times_deny, "阁下不忠不信，我不敢收你为徒。")}

      other_family?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :other_family_deny,
           "你既有了名师指点，就要勤下苦功，勿要三心二意！"
         )}

      is_integer(min_str) and student_attr(student, :str) < min_str ->
        {:error, deny_text(config, :str_deny, "连玄铁剑都拿不动，怎么做我徒弟。")}

      failing_skill = first_failing_recruit_skill(student, min_skills, skill_order) ->
        {:error, min_skills_deny(config, failing_skill)}

      is_integer(min_max_neili) and
          (student_max_neili(student) || 0) < min_max_neili ->
        {:error, deny_text(config, :max_neili_deny, "你把内力锻炼好了再来也不迟啊！")}

      true ->
        {:ok, accept}
    end
  end

  # #1010 红花会 honghua.h 三条共用 permit 门（9/11 clone_lib NPC 调用）。
  # 返回 nil 表示放行；返回 {:error, text} 供各 NPC 门序直接短路。
  defp honghua_permit_error(student, config, family_name) do
    cond do
      betrayed_sect?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :betray_sect_deny,
           "我们红花会四大戒条你还记得吗？亏你还有脸回来！"
         )}

      betrayed_before?(student) ->
        {:error, deny_text(config, :betray_times_deny, "哼，阁下不忠不信，我们红花会可不会收留。")}

      other_family?(student, family_name) ->
        {:error, deny_text(config, :other_family_deny, "阁下既有了师承，还来我们红花会做什么？")}

      true ->
        nil
    end
  end

  # #1010 陈家洛 chen.c:129-167：permit → shen → combat_exp → honghua-xinfa → max_neili。
  defp honghua_chen_recruit_gate(student, config, family_name) do
    case honghua_permit_error(student, config, family_name) do
      {:error, _reason} = error ->
        error

      nil ->
        stats = student_stats(student)
        shen = Map.get(stats, :shen, 0) || 0
        exp = Map.get(stats, :combat_exp, 0) || 0
        min_shen = Map.get(config, :min_shen, 0) || 0
        min_exp = Map.get(config, :min_exp, 0) || 0
        min_skills = Map.get(config, :min_skills, %{}) || %{}
        skill_order = Map.get(config, :recruit_skill_order, []) || []
        min_max_neili = Map.get(config, :min_max_neili)
        accept = deny_text(config, :accept_msg, "不错，不错。念在你如此有心，今日我便收下你。")

        cond do
          shen < min_shen ->
            {:error,
             deny_text(
               config,
               :min_shen_deny,
               "我红花会乃为救天下苍生而建，所做的一切无不以侠义为重。阁下在德行方面，似乎还做得不够。"
             )}

          exp < min_exp ->
            {:error,
             deny_text(
               config,
               :min_exp_deny,
               "你的江湖经验太浅，我就算收了你，恐怕你也难有所作为。"
             )}

          failing = first_failing_recruit_skill(student, min_skills, skill_order) ->
            {:error, min_skills_deny(config, failing)}

          is_integer(min_max_neili) and (student_max_neili(student) || 0) < min_max_neili ->
            {:error,
             deny_text(
               config,
               :max_neili_deny,
               "我的武功全需强大的内功为辅，阁下似乎应该多练练内力。"
             )}

          true ->
            {:ok, accept}
        end
    end
  end

  # #1010 余鱼同 yu.c:95-102：先 permit_recruit，再无条件拒绝（differ from deny_all）。
  defp honghua_yu_recruit_gate(student, config, family_name) do
    case honghua_permit_error(student, config, family_name) do
      {:error, _reason} = error ->
        error

      nil ->
        {:error, deny_text(config, :deny_msg, "我不收徒，你找其余几位当家的好了。")}
    end
  end

  # #951 全真教 `kungfu/class/quanzhen/*.c`：quanzhen.h permit_recruit 三条为所有
  # 可收徒 NPC 共用；之后各 NPC 门序互不相同，按 recruit_profile 分派。
  # 门序与拒绝文案逐条对齐 LPC；ji.c / pi.c 走 deny_all，不进入本函数。
  defp quanzhen_recruit_gate(
         student,
         config,
         exp,
         family_name,
         profile,
         min_skills,
         any_min_skills
       ) do
    shen = Map.get(student_stats(student), :shen, 0) || 0
    accept = deny_text(config, :accept_msg, "好吧，我就收下你这个徒弟。")

    cond do
      # quanzhen.h 三条，顺序与 LPC 逐条 return 一致。
      betrayed_sect?(student, family_name) ->
        {:error, deny_text(config, :betray_sect_deny, "你当年既然离开全真教，何必又要回来？")}

      betrayed_before?(student) ->
        {:error, deny_text(config, :betray_times_deny, "我们全真教乃名门正派，决不收判师之徒！")}

      other_family?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :other_family_deny,
           "你既然已经有了名师指点，不好好学习，来我们全真教作甚？"
         )}

      # sun.c:92 只拒男性；LPC 不是「必须为女性」。
      profile == "sun" and student_gender(student) == "男性" ->
        {:error, deny_text(config, :gender_deny, "我不收男徒，你还是去拜我几位师兄为师吧。")}

      # wang.c:130 int 硬门位于其它 attempt_apprentice 门之前。
      profile == "wang" and
          (student_int(student) || 0) < (Map.get(config, :hard_min_int) || 0) ->
        {:error, deny_text(config, :int_deny, "你的悟性还不够，还是先找我那几个徒弟学习吧。")}

      profile == "zhou" and exp < (Map.get(config, :min_exp) || 0) ->
        {:error, deny_text(config, :min_exp_deny, "你经验这么差，还是去找我那几个师侄教你吧。")}

      # 内功 OR 门：xuanmen-neigong / quanzhen-xinfa 任一达到阈值即通过。
      profile in ["hao", "liu", "ma", "qiu", "sun", "tan", "wang", "wangchuyi", "yin"] and
          any_min_skills_failing?(student, any_min_skills) ->
        {:error,
         deny_text(
           config,
           :any_min_skills_deny,
           "你的本门内功心法火候不足，难以领略更高深的武功。"
         )}

      profile in ["qiu"] and quanzhen_skill_below?(student, min_skills, "sword") ->
        {:error, deny_text(config, :sword_deny, "你的剑法差成这样，如何能够杀敌？")}

      profile in ["hao", "liu", "sun", "tan", "wangchuyi"] and
          quanzhen_skill_below?(student, min_skills, "taoism") ->
        {:error,
         deny_text(
           config,
           :taoism_deny,
           "你在修身养性方面还需多加锻炼，等你道学心法够高后再来吧。"
         )}

      profile == "ma" and quanzhen_skill_below?(student, min_skills, "taoism") ->
        {:error,
         deny_text(
           config,
           :taoism_deny,
           "你在修身养性方面还需多加锻炼，等你道学心法够高后再来吧。"
         )}

      # ma.c:114 / wang.c:145：经验门在技能门之后、侠义门之前。
      profile in ["ma", "wang"] and exp < (Map.get(config, :min_exp) || 0) ->
        {:error, deny_text(config, :min_exp_deny, "你的实战经验太差，看来难以领略更高深的武功。")}

      shen < (Map.get(config, :min_shen) || 0) ->
        {:error, deny_text(config, :min_shen_deny, "你行侠仗义之事做得太少，我不能收你。")}

      true ->
        {:ok, accept}
    end
  end

  defp quanzhen_skill_below?(student, skills, skill) do
    skill_level(student, skill) < (Map.get(skills, skill) || 0)
  end

  # #903 桃花岛 `kungfu/class/taohua/{feng,lu,qu,huang}.c attempt_apprentice`：
  # feng/lu/qu 只认黄药师写在 temp["taohua/master"] 上的指派；huang 低经验时
  # 随机指派一名弟子（置 family=桃花岛 但**不** recruit，LPC 原样），高经验直收。
  defp taohua_recruit_gate(student, config, exp, family_name) do
    mark_key = Map.get(config, :master_mark)
    mark_value = if is_binary(mark_key), do: student_mark(student, mark_key), else: nil

    case Map.get(config, :master_name) do
      master when is_binary(master) ->
        cond do
          mark_value in [nil, 0, false] ->
            {:error,
             deny_text(
               config,
               :master_absent_msg,
               "我可不敢擅自收徒，你还是找家师黄岛主吧！"
             )}

          to_string(mark_value) != master ->
            {:error,
             fill_master(
               deny_text(
                 config,
                 :master_reject_msg,
                 "家师不是让你拜%master%的吗？你怎么来找我来了？"
               ),
               to_string(mark_value)
             )}

          true ->
            {:ok,
             deny_text(
               config,
               :master_accept_msg,
               "好吧，既然家师有令，我就收下你了，不过要好好遵守桃花岛的规矩。\n"
             )}
        end

      _ ->
        defer_max = Map.get(config, :exp_defer_max) || 0

        if exp < defer_max do
          cond do
            mark_value not in [nil, 0, false] ->
              {:error,
               fill_master(
                 deny_text(config, :defer_mark_msg, "不是让你和%master%学艺吗？你怎么回事？"),
                 to_string(mark_value)
               )}

            student_family_name(student) == family_name and
                student_master_name(student) not in [nil, ""] ->
              {:error,
               fill_master(
                 deny_text(
                   config,
                   :defer_master_msg,
                   "你好好跟%master%学艺，水平到了老夫自然会亲自点拨你。"
                 ),
                 student_master_name(student)
               )}

            true ->
              masters = Map.get(config, :defer_masters, []) || []
              master = if masters == [], do: "黄药师", else: Enum.random(masters)

              text =
                fill_master(
                  deny_text(
                    config,
                    :defer_msg,
                    "嗯…念你长途跋涉赶来拜师，老夫就收你入桃花岛。不过你武学方面成就有限，还是先跟我弟子%master%学习吧。\n"
                  ),
                  master
                )

              {:defer, text, {mark_key, master}}
          end
        else
          {:ok, deny_text(config, :accept_msg, "很好，很好。\n")}
        end
    end
  end

  defp student_mark(student, mark) when is_binary(mark) do
    meta = meta_of(student)
    marks = Map.get(meta, :marks) || Map.get(meta, :env) || %{}
    Map.get(marks, mark)
  end

  # #789 武当派 wudang.h permit_recruit（已在上面统一判定）+ 9 位师父 attempt_apprentice：
  # 各 NPC 门控顺序互不相同，按 recruit_profile 分派。全部逐字对齐 LPC。
  defp wudang_recruit_gate(
         student,
         config,
         exp,
         _family_name,
         profile,
         min_skills,
         pre_min_skills
       ) do
    case profile do
      "zhang" -> wudang_zhang_gate(student, config, exp, min_skills)
      "shan" -> wudang_shan_gate(student, config, min_skills)
      "yan" -> wudang_yan_gate(student, config, min_skills, pre_min_skills)
      "guxu" -> wudang_guxu_gate(student, config)
      _ -> wudang_standard_gate(student, config, exp, min_skills)
    end
  end

  defp wudang_below?(value, need), do: is_integer(need) and value < need

  defp wudang_err(config, key, default), do: {:error, ensure_lf(deny_text(config, key, default))}

  # zhang.c: xinfa120 → shen80000 → exp500000 → taoism120 → int32(硬)
  defp wudang_zhang_gate(student, config, exp, min_skills) do
    shen = Map.get(student_stats(student), :shen, 0) || 0
    int = student_int(student)

    cond do
      wudang_below?(skill_level(student, "wudang-xinfa"), Map.get(min_skills, "wudang-xinfa")) ->
        wudang_err(
          config,
          :xinfa_deny,
          "我武当派乃内家武功，最重视内功心法。%respect%是否还应该在武当心法上多下点功夫？"
        )

      shen < (Map.get(config, :min_shen, 0) || 0) ->
        wudang_err(
          config,
          :shen_deny,
          "学武之人，德义为先，功夫的高低倒还在其次，未练武，要先学做人。在德行方面，%respect%是否还做得不够？"
        )

      exp < (Map.get(config, :min_exp, 0) || 0) ->
        wudang_err(config, :exp_deny, "你现在经验尚浅，不能领会高深的武功，先锻炼要紧。")

      wudang_below?(skill_level(student, "taoism"), Map.get(min_skills, "taoism")) ->
        wudang_err(
          config,
          :taoism_deny,
          "我武当派武功全从道藏悟出。你对道家心法的领悟还不够。%respect%还是多研究研究道学心法吧。"
        )

      not is_nil(Map.get(config, :hard_min_int)) and int < Map.fetch!(config, :hard_min_int) ->
        wudang_err(
          config,
          :int_deny,
          "我武当派武功极需靠自己领悟。要能达到炉火纯青之境，体质什么的倒是无关紧要，悟性却是半点也马虎不得。%respect%的悟性还大有潜力可挖，还是请回吧。"
        )

      true ->
        :ok
    end
  end

  # shan.c: int30(硬) → shen8000 → xinfa70 → taoism70
  defp wudang_shan_gate(student, config, min_skills) do
    shen = Map.get(student_stats(student), :shen, 0) || 0

    cond do
      not is_nil(Map.get(config, :hard_min_int)) and
          student_int(student) < Map.fetch!(config, :hard_min_int) ->
        wudang_err(config, :int_deny, "你的资质还没到铁划银钩的境界，收你也是白搭。")

      shen < (Map.get(config, :min_shen, 0) || 0) ->
        wudang_err(
          config,
          :shen_deny,
          "我武当乃是堂堂名门正派，对弟子要求极严。在德行方面，%respect%是否还做得不够？"
        )

      wudang_below?(skill_level(student, "wudang-xinfa"), Map.get(min_skills, "wudang-xinfa")) ->
        wudang_err(
          config,
          :xinfa_deny,
          "我武当派最注重内功心法%respect%是否应该在武当心法上多下点功夫啊?"
        )

      wudang_below?(skill_level(student, "taoism"), Map.get(min_skills, "taoism")) ->
        wudang_err(
          config,
          :taoism_deny,
          "习武是为了强身健体，一味的练武是不可取的。我看你还需要在修身养性方面多锻炼锻炼，以提高你的道德心法。"
        )

      true ->
        :ok
    end
  end

  # yan.c: xinfa30(提示「太极神功」) → shen10000 → xinfa70 → taoism70
  defp wudang_yan_gate(student, config, min_skills, pre_min_skills) do
    shen = Map.get(student_stats(student), :shen, 0) || 0

    cond do
      wudang_below?(skill_level(student, "wudang-xinfa"), Map.get(pre_min_skills, "wudang-xinfa")) ->
        wudang_err(
          config,
          :pre_xinfa_deny,
          "我武当派乃内家武功，最重视内功心法。%respect%是否还应该在太极神功上多下点功夫？"
        )

      shen < (Map.get(config, :min_shen, 0) || 0) ->
        wudang_err(
          config,
          :shen_deny,
          "我武当乃是堂堂名门正派，对弟子要求极严。在德行方面，%respect%是否还做得不够？"
        )

      wudang_below?(skill_level(student, "wudang-xinfa"), Map.get(min_skills, "wudang-xinfa")) ->
        wudang_err(
          config,
          :xinfa_deny,
          "我武当派最注重内功心法%respect%是否应该在武当心法上多下点功夫啊?"
        )

      wudang_below?(skill_level(student, "taoism"), Map.get(min_skills, "taoism")) ->
        wudang_err(
          config,
          :taoism_deny,
          "习武是为了强身健体，一味的练武是不可取的！我看你还需要在修身养性方面多锻炼锻炼，以提高你的道德心法。"
        )

      true ->
        :ok
    end
  end

  # guxu.c: shen >= 0
  defp wudang_guxu_gate(student, config) do
    shen = Map.get(student_stats(student), :shen, 0) || 0

    if shen < (Map.get(config, :min_shen, 0) || 0) do
      wudang_err(
        config,
        :shen_deny,
        "我武当乃是堂堂名门正派，对弟子要求极严。在德行方面，%respect%是否还做得不够？"
      )
    else
      :ok
    end
  end

  # standard（mo/song/xi/yin/yu）: shen → exp(有配置才判) → xinfa → taoism
  defp wudang_standard_gate(student, config, exp, min_skills) do
    shen = Map.get(student_stats(student), :shen, 0) || 0
    min_exp = Map.get(config, :min_exp, 0) || 0

    cond do
      shen < (Map.get(config, :min_shen, 0) || 0) ->
        wudang_err(
          config,
          :shen_deny,
          "我武当乃是堂堂名门正派，对弟子要求极严。在德行方面，%respect%是否还做得不够？"
        )

      min_exp > 0 and exp < min_exp ->
        wudang_err(config, :exp_deny, "你现在经验尚浅，不能领会高深的武功，先锻炼要紧。")

      wudang_below?(skill_level(student, "wudang-xinfa"), Map.get(min_skills, "wudang-xinfa")) ->
        wudang_err(
          config,
          :xinfa_deny,
          "我武当派最注重内功心法%respect%是否应该在武当心法上多下点功夫啊?"
        )

      wudang_below?(skill_level(student, "taoism"), Map.get(min_skills, "taoism")) ->
        wudang_err(
          config,
          :taoism_deny,
          "习武是为了强身健体，一味的练武是不可取的。我看你还需要在修身养性方面多锻炼锻炼，以提高你的道德心法。"
        )

      true ->
        :ok
    end
  end

  defp fill_master(text, master) when is_binary(text),
    do: String.replace(text, "%master%", master)

  defp fill_master(text, _master), do: text

  defp student_int(character) do
    Map.get(Map.get(meta_of(character), :stats) || %{}, :int, 0) || 0
  end

  # #832 王维扬 wangweiyang.c:149 `query_int() < N && query_con() < N`。
  # LPC 的 query_int/query_con 是派生值（base + tattoo + reborn + 技能加成 + temp），
  # 故统一组装成 %Stats{} 后交给 Stats.query_int/query_con，避免裸 stats.int/con
  # 丢掉 literate/force 加成。已加载的真实角色 stats 本身即 %Stats{}，逐字段透传。
  # 两项必须「同时」低于阈值才返回 true（LPC 的 &&，不是 gaibang 的 OR 门）。
  defp both_query_attrs_below?(student, threshold) do
    raw = student_stats_of(student)

    stats = %Stats{
      int: Map.get(raw, :int) || Map.get(raw, "int") || 0,
      con: Map.get(raw, :con) || Map.get(raw, "con") || 0,
      skills: Map.get(raw, :skills) || Map.get(raw, "skills") || %{},
      tattoo: Map.get(raw, :tattoo) || %{},
      reborn: Map.get(raw, :reborn) || %{}
    }

    Stats.query_int(stats) < threshold and Stats.query_con(stats) < threshold
  end

  # #804 逍遥派 xiaoyao.h `query("per")`：容貌取自 stats.per。
  defp student_per(character) do
    Map.get(Map.get(meta_of(character), :stats) || %{}, :per, 0) || 0
  end

  # #804 无崖子：任一内功达到门槛即通过（OR），全部不足才拒绝。
  defp any_min_skills_failing?(character, skills) when is_map(skills) and map_size(skills) > 0 do
    Enum.all?(skills, fn {skill, level} -> skill_level(character, skill) < level end)
  end

  defp any_min_skills_failing?(_character, _skills), do: false

  # #903 桃花岛黄药师 ask_skill6：入参是 normalize_stats/1 后的 stats map，
  # 没有 meta，故不能复用面向 character 的 any_min_skills_failing?/2。
  defp any_min_skills_failing_stats?(player, skills)
       when is_map(skills) and map_size(skills) > 0 do
    # inquiries 的 inline map 保留 atom 键（如 :bibo_shengong）；skill_level_of
    # 的 `_`→`-` 兜底只处理 binary，故先统一转字符串再查。
    Enum.all?(skills, fn {skill, level} ->
      key = if is_binary(skill), do: skill, else: to_string(skill)
      skill_level_of(player, key) < level
    end)
  end

  defp any_min_skills_failing_stats?(_player, _skills), do: false

  defp student_wpk(character) do
    meta = meta_of(character)

    Map.get(Map.get(meta, :combat) || %{}, :WPK) ||
      Map.get(student_env(character), :WPK) ||
      Map.get(student_env(character), "WPK")
  end

  defp teaches?(character, skill), do: skill_level(character, skill) > 0

  defp normalize_skill(skill) when is_binary(skill), do: String.replace(skill, "_", "-")
  defp normalize_skill(skill) when is_atom(skill), do: skill |> to_string() |> normalize_skill()

  defp skill_level(character, skill) do
    stats = Map.get(meta_of(character), :stats)
    Map.get(Map.get(stats || %{}, :skills) || %{}, skill, 0)
  end

  # LPC `query("no_teach/" + skill)`：师父逐技能拒教。loader 把 UCL 的
  # `teach.no_teach = { skill = "..." }` 归一到 `meta.teach.no_teach_deny`。
  defp no_teach_reason(teacher, skill) when is_binary(skill) do
    teach = Map.get(meta_of(teacher), :teach) || %{}

    case Map.get(teach, :no_teach_deny) || Map.get(teach, "no_teach_deny") do
      denies when is_map(denies) ->
        text =
          Map.get(denies, skill) ||
            Map.get(denies, String.replace(skill, "_", "-")) ||
            Map.get(denies, String.replace(skill, "-", "_"))

        if is_binary(text) and byte_size(text) > 0, do: ensure_lf(text), else: nil

      _ ->
        nil
    end
  end

  defp no_teach_reason(_teacher, _skill), do: nil

  # 收徒门控的逐技能拒绝文案：华山岳不群/岳夫人对「心法不足」与「剑法不足」
  # 各有一句 LPC 原文（#740），故返回首个未达标技能 id 再按 UCL map 取文案。
  defp first_failing_recruit_skill(character, min_skills, order)
       when is_map(min_skills) and is_list(order) and order != [] do
    ordered =
      Enum.find(order, fn skill ->
        is_binary(skill) and Map.has_key?(min_skills, skill) and
          skill_level(character, skill) < Map.fetch!(min_skills, skill)
      end)

    case ordered do
      skill when is_binary(skill) -> skill
      _ -> first_failing_recruit_skill(character, min_skills, [])
    end
  end

  defp first_failing_recruit_skill(character, min_skills, _order) when is_map(min_skills) do
    case Enum.find(min_skills, fn {skill, level} -> skill_level(character, skill) < level end) do
      {skill, _level} -> skill
      nil -> nil
    end
  end

  defp first_failing_recruit_skill(_character, _min_skills, _order), do: nil

  defp min_skills_deny(config, skill) do
    default = "你根基尚浅，这几样本事还未练成，先回去打好基础再来吧。\n"

    case Map.get(config, :min_skills_deny) do
      denies when is_map(denies) -> ensure_lf(Map.get(denies, skill) || default)
      text when is_binary(text) and byte_size(text) > 0 -> ensure_lf(text)
      _ -> default
    end
  end

  # ---- inquiry_grant 内部（%Stats{} / map 归一为 map，family 走 Map.get） ----

  # `Map.from_struct/1` 会丢掉调用方补的非结构体键（:family / :max_neili /
  # :master_id），故归一后把这些键显式搬回来（缺省 nil 由各门控自己判）。
  defp normalize_stats(%Stats{} = stats) do
    stats
    |> Map.from_struct()
    |> Map.put(:family, Map.get(stats, :family))
    |> Map.put(:max_neili, Map.get(stats, :max_neili))
    |> Map.put(:master_id, Map.get(stats, :master_id))
  end

  defp normalize_stats(%{} = stats), do: stats
  defp normalize_stats(_), do: %{}

  defp perform_known?(player, perform_id),
    do: MapSet.member?(Map.get(player, :performs) || MapSet.new(), perform_id)

  defp skill_level_of(player, skill) do
    skills = Map.get(player, :skills) || %{}

    case Map.get(skills, skill, 0) do
      0 when is_binary(skill) ->
        Map.get(skills, String.replace(skill, "_", "-"), 0) || 0

      level ->
        level || 0
    end
  end

  defp stat(player, key), do: Map.get(player, key) || 0

  # 两方都带 :family 才比较，缺失不拦（无从判定）
  defp same_family?(player, npc) do
    case {Map.get(player, :family), Map.get(npc, :family)} do
      {player_family, npc_family} when is_binary(player_family) and is_binary(npc_family) ->
        player_family == npc_family

      _ ->
        true
    end
  end

  # #852 LPC `me->query("family/master_id") != query("id")`：
  # 玩家 meta.family.master_id 由调用侧并入 stats，NPC id 由问询回执并入 npc_stats。
  # 两者都是 binary 且相等才算直传弟子；缺失不视为通过。
  defp direct_disciple?(player, npc) do
    master_id = Map.get(player, :master_id)
    npc_id = Map.get(npc, :id)

    is_binary(master_id) and is_binary(npc_id) and master_id == npc_id
  end

  defp meets_levels?(player, min_levels) when is_map(min_levels),
    do: Enum.all?(min_levels, fn {skill, level} -> skill_level_of(player, skill) >= level end)

  defp meets_levels?(_player, _min_levels), do: true

  # #921 铁掌帮：masterd.c 的 b["neili"] 是 max_neili 伪技能键；loader 归一后为
  # "max-neili"。lpc_masterd 的有序链已用 named_level_value/2，但无序回退仍用
  # meets_levels?/2 的纯技能查表，会把 max_neili=200 当作技能 0 误拒。
  # 仅 masterd 路径改用命名值查表，其它 gate_order 零影响。
  defp meets_named_levels?(player, min_levels) when is_map(min_levels),
    do: Enum.all?(min_levels, fn {key, min} -> named_level_value(player, key) >= min end)

  defp meets_named_levels?(_player, _min_levels), do: true
end

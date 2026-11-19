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
      # #742/#752：LPC `no_teach/<skill>` 是 learn 的逐技能硬拒，且文案逐 NPC 不同。
      # loader 已把 map 形态落为 teach.no_teach_deny；此前无消费端导致文案静默丢弃。
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

  @doc """
  收徒门槛（UCL apprentice 段：min_shen/min_exp/min_skills + 性别/permit 门控）

  门控顺序忠实对应 LPC `attempt_apprentice`：
  1. `permit_recruit`（shaolin.h）：detach/betrayer/他派三条；
  2. `gender`（清无/清为/清法）：性别不符分别拒绝（女性/无性文案不同）；
  3. min_shen / min_exp / min_skills（既有）。

  `gate` 为 nil 时退化到既有门派行为（无性别/permit 检查），保持向后兼容。
  """
  def recruit_gate?(teacher, student, gate \\ nil) do
    config = gate || apprentice_config(teacher)

    min_shen = Map.get(config, :min_shen, 0) || 0
    max_shen = Map.get(config, :max_shen)
    min_exp = Map.get(config, :min_exp, 0) || 0
    min_skills = Map.get(config, :min_skills, %{}) || %{}
    gender = Map.get(config, :gender)
    permit_recruit = Map.get(config, :permit_recruit) == true
    gate_order = Map.get(config, :gate_order, "permit_first")
    family_name = Map.get(config, :family)
    reject_master_name = Map.get(config, :reject_master_name)
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
    failing_recruit_skill = first_failing_recruit_skill(student, min_skills)

    # Task #644：gate_order 控制 permit_recruit 与 gender 检查先后。
    #   "gender_first"（清无 LPC qing-wu.c）：gender 先于 permit_recruit
    #   "permit_first"（缺省，清为/清法 LPC）：permit_recruit 先于 gender
    result =
      cond do
      # 性别门控（清无 gate_order="gender_first" 时置于 permit_recruit 之前，对齐 LPC）
      gate_order == "gender_first" and
          gender not in [nil, ""] and
          student_gender(student) != gender ->
        gender_deny(student, gender, config)

      # permit_recruit（kunlun.h / shaolin.h）三条，顺序与 LPC 一致。
      # #752 昆仑：UCL 可逐句覆写原文；未配置时保持少林缺省，老配置零回归。
      permit_recruit and betrayed_sect?(student, family_name) ->
        {:error,
         deny_text(config, :betray_sect_deny, "你反反复复，唉！怎么一心向佛？\n")}

      permit_recruit and betrayed_before?(student) ->
        {:error,
         deny_text(config, :betray_times_deny, "你大逆不道，私自判师，不能容于少林！\n")}

      permit_recruit and other_family?(student, family_name) ->
        {:error,
         deny_text(
           config,
           :other_family_deny,
           "你已经名师指点，为何不下苦功，反而来我们少林寺呢？\n"
         )}

      # #804 逍遥派 xiaoyao.h permit_recruit 第四条：`query("per") < 28`。
      # 位置紧随他派门，仍是 permit_recruit 内部，早于各 NPC 自门控。
      not is_nil(min_per) and (student_per(student) || 0) < min_per ->
        {:error,
         deny_text(config, :per_deny, "大侠的尊容未免次了点，这样可入不了本派！\n")}

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
        {:error,
         deny_text(config, :int_deny, "大侠悟性仍有不足，先回去多读点书吧。\n")}

      gate_order == "lpc_wuyazi" and exp < min_exp ->
        {:error, deny_text(config, :min_exp_deny, "你经验尚浅，武功未成，师父未同意收你为徒。\n")}

      # #804 苏星河 suxingh.c:123-134：先 int30（带 return），再 exp200000。
      gate_order == "lpc_xiaoyao" and
          not is_nil(hard_min_int) and (student_int(student) || 0) < hard_min_int ->
        {:error,
         deny_text(config, :int_deny, "大侠悟性仍有不足，先回去多读点书吧。\n")}

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
      not is_nil(promotion_reason) -> {:error, promotion_reason}

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

      gate_order != "lpc_wuyazi" and exp < min_exp ->
        {:error, deny_text(config, :min_exp_deny, "你经验尚浅，武功未成，师父未同意收你为徒。\n")}

      # 昆仑何足道 LPC `if (me->query_int() < 38) { ...; return; }` 是硬门，
      # 与达摩 min_int「只提示不拒」不同；二者分开配置，禁止互相复用。
      # 逍遥派两种 gate_order 已在上面按 LPC 顺序提前判定，此处跳过避免文案互换。
      gate_order not in ["lpc_xiaoyao", "lpc_wuyazi"] and
          not is_nil(hard_min_int) and (student_int(student) || 0) < hard_min_int ->
        {:error,
         deny_text(config, :int_deny, "大侠悟性仍有不足，先回去多读点书吧。\n")}

      gate_order != "lpc_wuyazi" and not is_nil(failing_recruit_skill) ->
        {:error, min_skills_deny(config, failing_recruit_skill)}

      true ->
        :ok
    end

    case {int_warning, result} do
      {nil, :ok} -> :ok
      {warning, :ok} when is_binary(warning) -> {:ok, warning}

      {warning, {:error, reason}} when is_binary(warning) and is_binary(reason) ->
        {:error, warning <> reason}

      {_warning, error} -> error
    end
  end

  # UCL 可用 *_deny 覆写 LPC 原文；未配置时用 plan §5.4 登记的缺省文案（含结尾换行）。
  defp deny_text(config, key, default) do
    case Map.get(config, key) do
      text when is_binary(text) and byte_size(text) > 0 -> ensure_lf(text)
      _ -> ensure_lf(default)
    end
  end

  defp ensure_lf(text), do: String.ends_with?(text, "\n") && text || text <> "\n"

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
            {:error,
             ensure_lf(
               Map.get(config, :promotion_deny) || "大侠，贫僧哪里敢当！\n"
             )}

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

  各门槛的拒绝文案可用同名 `*_deny` 键覆盖（`maxed` / `family_deny` /
  `skill_deny` / `max_shen_deny` / `gongxian_deny` / `shen_deny` /
  `level_deny` / `max_neili_deny` / `dex_deny` / `force_cap_deny` /
  `neili_cap_deny` / `perform_deny`），缺省用通用文案。
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

    cond do
      is_nil(perform_id) ->
        {:error, deny(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny(config, "maxed", "这一招你不是已经会了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny(config, "family_deny", "你我并非同门，何来讨教绝招之说？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error, deny(config, "skill_deny", "你连#{skill}都没学，还谈什么绝招可言？\n")}

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

      not meets_levels?(player, min_levels) ->
        {:error, level_deny_text(config, player, min_levels)}

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
    levels = Map.get(config, "min_levels", %{}) || %{}
    order = Map.get(config, "level_order") || []
    requires_perform = Map.get(config, "requires_perform")

    cond do
      is_nil(perform_id) ->
        {:error, deny_lf(config, "perform_deny", "这门绝招暂不外传。\n")}

      perform_known?(player, perform_id) ->
        {:error, deny_lf(config, "maxed", "咦？这招你不是已经会了吗？\n")}

      not same_family?(player, npc) ->
        {:error, deny_lf(config, "family_deny", "和本派素无瓜葛，何出此言？\n")}

      is_binary(skill) and skill_level_of(player, skill) < 1 ->
        {:error,
         deny_lf(config, "skill_deny", "你连这门功夫都没学，还谈什么绝招可言？\n")}

      stat(player, :gongxian) < min_gongxian ->
        {:error,
         deny_lf(
           config,
           "gongxian_deny",
           "你对本派所作出的贡献不够，这一招我暂时还不能传你。\n"
         )}

      is_binary(requires_perform) and not perform_known?(player, requires_perform) ->
        {:error,
         deny_lf(config, "requires_perform_deny", "要学此招，必须先通晓「乾坤劲」的奥秘。\n")}

      failing = first_failing_ordered_level(player, order, levels) ->
        {:error, ordered_level_deny(config, failing)}

      true ->
        {:ok, perform_id, cost}
    end
  end

  defp first_failing_ordered_level(player, order, levels) when is_list(order) and is_map(levels) do
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

      not is_nil(failing = first_failing_min_skill(player, Map.get(config, "min_skill_levels", %{}) || %{})) ->
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
        priority =
          [primary, "force", "dodge"]
          |> Enum.reject(fn key -> is_nil(key) or not Map.has_key?(min_levels, key) end)

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

  defp student_int(character) do
    Map.get(Map.get(meta_of(character), :stats) || %{}, :int, 0) || 0
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

  defp student_wpk(character) do
    meta = meta_of(character)

    Map.get(Map.get(meta, :combat) || %{}, :WPK) ||
      Map.get(student_env(character), :WPK) ||
      Map.get(student_env(character), "WPK")
  end

  defp teaches?(character, skill), do: skill_level(character, skill) > 0

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
  defp first_failing_recruit_skill(character, min_skills) when is_map(min_skills) do
    case Enum.find(min_skills, fn {skill, level} -> skill_level(character, skill) < level end) do
      {skill, _level} -> skill
      nil -> nil
    end
  end

  defp first_failing_recruit_skill(_character, _min_skills), do: nil

  defp min_skills_deny(config, skill) do
    default = "你根基尚浅，这几样本事还未练成，先回去打好基础再来吧。\n"

    case Map.get(config, :min_skills_deny) do
      denies when is_map(denies) -> ensure_lf(Map.get(denies, skill) || default)
      text when is_binary(text) and byte_size(text) > 0 -> ensure_lf(text)
      _ -> default
    end
  end

  # ---- inquiry_grant 内部（%Stats{} / map 归一为 map，family 走 Map.get） ----

  # `Map.from_struct/1` 会丢掉调用方补的非结构体键（:family / :max_neili），
  # 故归一后把这两个键显式搬回来（缺省 nil 由同门/内力门控自己判「不拦」）。
  defp normalize_stats(%Stats{} = stats) do
    stats
    |> Map.from_struct()
    |> Map.put(:family, Map.get(stats, :family))
    |> Map.put(:max_neili, Map.get(stats, :max_neili))
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

  defp meets_levels?(player, min_levels) when is_map(min_levels),
    do: Enum.all?(min_levels, fn {skill, level} -> skill_level_of(player, skill) >= level end)

  defp meets_levels?(_player, _min_levels), do: true
end

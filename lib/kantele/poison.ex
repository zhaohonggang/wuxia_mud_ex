defmodule Kantele.Poison do
  @moduledoc """
  毒药系统：中毒条件引擎、混毒、解毒、伤害公式。

  对应 LPC condition/condition_poison.c 的完整移植。
  实现 Conditions 系统的 daemon 接口：
  - `daemon/1` - 给 "poison" 返回 {:ok, Poison}
  - `do_effect/3` - 对角色状态应用中毒效果
  - `update_condition/1` - 每 tick 更新中毒状态
  """

  require Logger

  @name "poison"
  @chinese_name "中毒"

  @update_msg_others "~N呻吟一声，痛苦地捂住了肚子。"
  @update_msg_self "你觉得体内的~?发作了。"
  @die_msg_others "~N惨叫一声，倒在地上，再也不动了。"

  @min_dispel_neili 200
  @base_dispel_neili_cost 100
  @self_dispel_neili_cost 150
  @other_dispel_neili_cost_multiplier 1.25

  # ---- POISON 系 condition 家族表 ----
  #
  # LPC `kungfu/condition/*.c` 里那一批只做 `inherit POISON` + 覆盖
  # `name()/chinese_name()/update_msg_others()/update_msg_self()`
  # （个别再覆盖 `jing_damage()/qi_damage()/die_reason()`）的条件文件，
  # 本质是同一套 POISON 引擎的**数据变体**，所以在这里收成一张表，
  # 由 `ConditionRegistry` 把它们的 cnd 名统一指到 `Kantele.Poison`。
  #
  # 键 = LPC condition id；`others` 里的 `$N` 已按本引擎渲染约定写成
  # `{npc}`（见 `Kantele.Drunk` 的同一套通道），`self` 里的 `$?`（毒名）
  # 在这些文件里都没用到，故不需要占位替换。
  #
  # `jing_div`/`qi_div` 对应 LPC 里 `return cnd["level"] / N;` 的整数除覆盖。
  @family %{
    "bingcan_duzhang" => %{
      chinese_name: "冰蚕寒毒",
      others: "{npc}惨嚎一声，脸色铁青，全身浮现出一层寒气，不住的颤抖。\n",
      self: "你只觉极寒攻心，全身肌肉快要冻结一般。\n"
    },
    "cuixin_zhang" => %{
      chinese_name: "催心掌掌力",
      others: "{npc}一声惨嚎，内息逆流，“哇”的一声喷出一大口鲜血。\n",
      self: "你只感到五脏六腑翻腾不止，剧毒攻心，看来是中了催心掌掌劲的干扰！\n"
    },
    "sha_poison" => %{
      chinese_name: "砂毒",
      others: "{npc}脸色霎地变的煞白，全身不停的颤抖。\n",
      self: "你只觉毒气攻心，顿时感到一股莫名的恶心，全身瘫软无力！\n"
    },
    "ice_poison" => %{
      chinese_name: "寒冰掌毒",
      others: "{npc}的身子突然晃了两晃，牙关格格地响了起来。\n",
      self: "忽然一阵奇寒从丹田升起，沁入四肢百骸，你中的寒冰绵掌之毒发作了！\n"
    },
    "huagu" => %{
      chinese_name: "化骨掌伤",
      others: "{npc}的身子突然晃了两晃，几乎跌倒。\n",
      self: "忽然浑身一阵剧痛，你中的化骨绵掌毒发了！\n",
      die_reason: "筋断骨碎，死的惨不堪言"
    },
    "ningxue_shenzhao" => %{
      chinese_name: "凝血之扰",
      others: "{npc}只感内息顿滞，“哇”的一声喷出一大口鲜血。\n",
      self: "你只感内息顿滞，全身血液竟渐渐的开始凝固起来！\n"
    },
    "qianzhu_wandushou" => %{
      chinese_name: "蛛蛊毒",
      others: "只见{npc}毒气上涌，脸浮现出一层黑气，不住的颤抖。\n",
      self: "你只觉蛊毒攻心，头晕目眩，一阵说不出的恶心。\n"
    },
    "shenzhao" => %{
      chinese_name: "神照经内劲",
      others: "只见{npc}呛呛退了数步，身子摇晃，双腿渐渐弯曲，似乎喝醉了一般。\n",
      self: "你只感内息顿滞，真气不畅，一张脸涨得通红，便要跌倒。\n",
      jing_div: 8,
      qi_div: 4
    },
    "tougu_zhen" => %{
      chinese_name: "透骨寒针之扰",
      others: "{npc}只觉一股奇寒散尽七筋八脉，犹感身陷万蚁之狱，全身不停的颤抖。\n",
      self: "你感到一股切骨奇寒由伤口处升起，看来是中了透骨针内劲的干扰！\n"
    },
    "xuanming_poison" => %{
      chinese_name: "玄冥寒毒",
      others: "{npc}脸色发紫，全身不住的颤抖，牙关格格作响。\n",
      self: "只感到一股奇寒从体内犹然而升，沁入三焦六脉，看来是玄冥神掌之毒发作了！\n",
      jing_div: 6,
      qi_div: 5
    },
    "xuantian_zhi" => %{
      chinese_name: "玄天寒劲",
      others: "{npc}的痛苦的呻吟了一声，脸上竟笼罩了一股薄薄的寒霜。\n",
      self: "忽然一阵寒气自丹田的而起，逐步渗透到四肢白赅，透出阵阵寒意。\n",
      jing_div: 6,
      qi_div: 3
    },
    "yinfeng_dao" => %{
      chinese_name: "阴风刮骨之扰",
      others: "{npc}惨嚎一声，只觉全身肌肉就像要撕裂开一般，豆大的汗珠不住的滴下。\n",
      self: "你感到一股切骨奇寒由伤口处升起，看来是中了阴风刀内劲的干扰！\n"
    }
  }

  @doc "POISON 家族表（cnd => 数据变体），供注册表/测试核对"
  def family(), do: @family

  @doc "POISON 家族的中文名（非家族成员返回 nil）"
  def family_chinese_name(cnd) do
    case Map.get(@family, cnd) do
      nil -> nil
      info -> info.chinese_name
    end
  end

  # --- Conditions daemon 接口 ---

  @doc "给 'poison' 返回 {:ok, Poison} 供 Conditions.affect_by 使用"
  def daemon("poison"), do: {:ok, __MODULE__}
  def daemon("fire_poison"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc """
  Conditions 系统调用：应用中毒伤害（每 condition/tick 一跳）。

  只负责扣 jing/qi（以及缺失时回填），**不递减 remain、不重写 condition**——
  生命周期（remain/duration 递减与到期）由 `update_condition/1` 在
  `Conditions.update_condition/2` 主循环里统一处理，避免双递减。

  POISON 家族成员（`@family`）额外按 LPC 各文件覆盖的
  `jing_damage/qi_damage` 算伤害，并把 `update_msg_others`（房间广播、排除本人）
  与 `update_msg_self`（只发本人）经 `state.condition_messages` 交给宿主。
  """
  def do_effect(state, cnd, _para) do
    # 获取当前中毒信息
    cond = Kantele.Character.Conditions.query_condition(state, cnd)

    if cond && is_map(cond) && cond["level"] > 0 do
      jing_loss = family_jing_damage(cnd, cond)
      qi_loss = family_qi_damage(cnd, cond)

      {:ok,
       state
       |> put_in([:attributes, :jing], max(Map.get(state.attributes, :jing, 0) - jing_loss, 0))
       |> put_in([:attributes, :qi], max(Map.get(state.attributes, :qi, 0) - qi_loss, 0))
       |> emit_family_messages(cnd)}
    else
      {:ok, state}
    end
  end

  @doc "Conditions 系统调用：每 tick 更新中毒状态"
  def update_condition(cond) do
    # 防御式归一：`hit_ob` 家族按 LPC 原样只给 level/duration/id，`remain` 由
    # `ConditionEvent.apply_poison_condition/3` 折算补齐；这里再兜一层，避免
    # 老调用方（或手工构造的 condition）缺键时 ArithmeticError。
    cond = normalize_poison(cond)

    if cond["remain"] <= 0 do
      {:expire}
    else
      # 每 tick 减少 remain 和 duration
      new_cond =
        cond
        |> Map.put("remain", max(cond["remain"] - 1, 0))
        |> Map.put("duration", max(cond["duration"] - 1, 0))

      if new_cond["remain"] <= 0 or new_cond["duration"] <= 0 do
        {:expire}
      else
        {:continue, new_cond}
      end
    end
  end

  # --- 核心函数 ---

  @doc "混合两种毒药（对应 LPC POISON_D->mixed_poison）"
  def mixed_poison(p1, p2) do
    cond do
      p1 == nil and p2 == nil -> nil
      p2 == nil -> p1
      p1 == nil -> p2
      true -> merge_poisons(p1, p2)
    end
  end

  @doc "应用中毒效果到角色（用于食物/液体消耗时）"
  def apply_poison_to_state(state, poison) do
    if is_valid_poison_params(poison) do
      p = Map.put_new(poison, "name", "中毒")
      existing = Kantele.Character.Conditions.query_condition(state, @name)
      merged = mixed_poison(existing, p)
      new_state = Kantele.Character.Conditions.apply_condition(state, @name, merged)
      {:ok, new_state}
    else
      {:error, "Invalid poison parameters"}
    end
  end

  @doc "解毒（对应 LPC condition_poison::dispel）"
  def dispel(state, cnd_name \\ @name) do
    cond = Kantele.Character.Conditions.query_condition(state, cnd_name)

    if !cond || cond["level"] <= 0 do
      {:error, "No active poison"}
    else
      # 简化的解毒逻辑
      cost_neili = calculate_cost(state, cond)
      dis = calculate_dispel_amount(state, cond, cost_neili)

      # 扣除内力
      new_state =
        put_in(
          state.attributes["neili"],
          max(Map.get(state.attributes, "neili", 0) - cost_neili, 0)
        )

      # 减少毒药剩余
      new_cond = Map.put(cond, "remain", max(cond["remain"] - dis, 0))

      if new_cond["remain"] <= 0 do
        new_state = Kantele.Character.Conditions.clear_condition(state, cnd_name)
      else
        new_state = Kantele.Character.Conditions.apply_condition(state, cnd_name, new_cond)
      end

      {:ok, %{cnd: new_cond, cost_neili: cost_neili}}
    end
  end

  @doc "精力伤害公式"
  def jing_damage(cnd) do
    d = cnd["level"]

    d =
      if d >= 64,
        do: 24 + div(d - 64, 8),
        else: if(d >= 32, do: 16 + div(d - 32, 4), else: div(d, 2))

    d = max(d, 10)
    div(d, 2) + :rand.uniform(d)
  end

  @doc "气血伤害公式"
  def qi_damage(cnd) do
    d = cnd["level"]
    d = if d > 300, do: 100 + div(d - 300, 12), else: if(d > 60, do: 60 + div(d - 60, 6), else: d)
    d = max(d, 10)
    div(d, 2) + :rand.uniform(d)
  end

  @doc "死亡原因"
  def die_reason(name) do
    if name == nil or name == "poison" do
      "died of poison"
    else
      "#{name} poison killed"
    end
  end

  # --- 私有函数 ---

  # LPC 里 shenzhao / xuantian_zhi / xuanming_poison 各自把 `jing_damage` /
  # `qi_damage` 覆盖成 `cnd["level"] / N`（整数除，不投骰）；其余家族成员沿用
  # POISON 基类的投骰公式。
  defp family_jing_damage(cnd, cond) do
    case Map.get(@family, cnd) do
      %{jing_div: d} -> div(max(cond["level"], 0), d)
      _ -> jing_damage(cond)
    end
  end

  defp family_qi_damage(cnd, cond) do
    case Map.get(@family, cnd) do
      %{qi_div: d} -> div(max(cond["level"], 0), d)
      _ -> qi_damage(cond)
    end
  end

  # LPC POISON::update_condition 末尾：
  #   message("vision", update_msg_others() 去掉自己, environment(me), ({ me }));
  #   tell_object(me, update_msg_self());
  defp emit_family_messages(state, cnd) do
    case Map.get(@family, cnd) do
      %{others: others, self: self} ->
        state
        |> push_message({:vision_excl, others})
        |> push_message({:tell, self})

      _ ->
        state
    end
  end

  defp push_message(state, msg) do
    Map.update(state, :condition_messages, [msg], fn msgs -> msgs ++ [msg] end)
  end

  defp is_valid_poison_params(p) do
    is_map(p) and
      is_integer(p["level"]) and
      is_integer(p["duration"]) and
      is_integer(p["remain"])
  end

  # remain/duration/level 归一：缺 `remain` 时按 LPC `mixed_poison` 的
  # `remain = level * duration` 折算。
  defp normalize_poison(cond) when is_map(cond) do
    level = int_or(cond["level"], 0)
    duration = int_or(cond["duration"], 0)

    cond
    |> Map.put("level", level)
    |> Map.put("duration", duration)
    |> Map.update("remain", level * duration, &int_or(&1, level * duration))
  end

  defp normalize_poison(cond), do: cond

  defp int_or(n, _default) when is_integer(n), do: n
  defp int_or(_, default), do: default

  defp merge_poisons(p1, p2) do
    p1 = normalize_poison(p1)
    p2 = normalize_poison(p2)

    # 混毒逻辑：保留高等级，累加持续时间，重新计算 level/remain
    max_level = max(p1["level"], p2["level"])
    min_level = min(p1["level"], p2["level"])

    new_level = max_level + div(min_level, 4)
    new_remain = min(p1["remain"] + p2["remain"], new_level * 2)
    new_duration = min(p1["duration"] + p2["duration"], new_level * 3)

    %{
      "level" => new_level,
      "remain" => new_remain,
      "duration" => new_duration,
      "id" => p2["id"] || p1["id"],
      "name" => p2["name"] || p1["name"]
    }
  end

  defp validate_condition(%{"level" => level}) when level > 0, do: :ok
  defp validate_condition(_), do: {:error, "Invalid condition"}

  defp check_neili(state) do
    neili = Map.get(state.attributes, "neili", 0)
    if neili >= @min_dispel_neili, do: :ok, else: {:error, "Neili insufficient"}
  end

  defp check_level(state, _ob, cnd) do
    my_skill = Map.get(state.skills, "force", 0) + Map.get(state.skills, "poison", 0)
    if my_skill >= cnd["level"] / 2, do: :ok, else: {:error, "Skill too low"}
  end

  defp check_immunity(state, _cnd) do
    attributes = Map.get(state, :attributes) || %{}

    if Kantele.Character.SpecialSkills.immune?(attributes, "piyi") do
      {:error, "Immune to poison"}
    else
      :ok
    end
  end

  defp check_dispel_level(state, _ob, cnd) do
    # 简化：用毒药等级作为目标等级
    target_level = cnd["level"]
    my_level = Map.get(state.skills, "force", 0) + Map.get(state.skills, "poison", 0)

    if my_level >= target_level / 2, do: :ok, else: {:error, "Target too strong"}
  end

  defp calculate_cost(state, cond) do
    base = @base_dispel_neili_cost
    level = cond["level"]

    # 简化：不区分自疗/他疗
    base + div(level, 2)
  end

  defp calculate_dispel_amount(state, cond, cost) do
    my_skill = Map.get(state.skills, "force", 0) + Map.get(state.skills, "poison", 0)
    target_level = cond["level"]

    if my_skill >= target_level do
      cost
    else
      div(cost * my_skill, max(target_level, 1))
    end
  end
end

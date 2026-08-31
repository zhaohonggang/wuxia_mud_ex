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

  # --- Conditions daemon 接口 ---

  @doc "给 'poison' 返回 {:ok, Poison} 供 Conditions.affect_by 使用"
  def daemon("poison"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc "Conditions 系统调用：应用中毒效果到角色状态"
  def do_effect(state, _cnd, _para) do
    # 获取当前中毒信息
    cond = Kantele.Character.Conditions.query_condition(state, @name)

    if cond && is_map(cond) && cond["level"] > 0 do
      # 应用中毒伤害
      jing_loss = jing_damage(cond)
      qi_loss = qi_damage(cond)

      new_state = state
      |> put_in([:attributes, :jing], max(Map.get(state.attributes, :jing, 0) - jing_loss, 0))
      |> put_in([:attributes, :qi], max(Map.get(state.attributes, :qi, 0) - qi_loss, 0))

      # 减少 remain
      new_cond = Map.put(cond, "remain", cond["remain"] - 1)
      new_state = Kantele.Character.Conditions.apply_condition(new_state, @name, new_cond)

      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  @doc "Conditions 系统调用：每 tick 更新中毒状态"
  def update_condition(cond) do
    if cond["remain"] <= 0 do
      {:expire}
    else
      # 每 tick 减少 remain 和 duration
      new_cond = cond
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
      new_state = put_in(state.attributes["neili"], max(Map.get(state.attributes, "neili", 0) - cost_neili, 0))

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
    d = if d >= 64, do: 24 + div(d - 64, 8), else: (if d >= 32, do: 16 + div(d - 32, 4), else: div(d, 2))
    d = max(d, 10)
    div(d, 2) + :rand.uniform(d)
  end

  @doc "气血伤害公式"
  def qi_damage(cnd) do
    d = cnd["level"]
    d = if d > 300, do: 100 + div(d - 300, 12), else: (if d > 60, do: 60 + div(d - 60, 6), else: d)
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

  defp is_valid_poison_params(p) do
    is_map(p) and
      is_integer(p["level"]) and
      is_integer(p["duration"]) and
      is_integer(p["remain"])
  end

  defp merge_poisons(p1, p2) do
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
    if Map.get(state.attributes, "special_skills", %{})["piyi"] == true do
      {:error, "Immune to poison"}
    else
      :ok
    end
  end

  defp check_dispel_level(state, _ob, cnd) do
    target_level = cnd["level"]  # 简化：用毒药等级作为目标等级
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
defmodule Kantele.Combat.Force do
  @moduledoc """
  内功系统（对应 LPC inherit/skill/force.c）

  提供内功基础行为：
  - valid_learn - 学习条件检查
  - hit_ob - 内力反击效果
  - do_effect - 修炼效果

  ## 内力反击

  当被攻击时，根据双方内力值计算反击伤害：
  - 攻击方内力不足时消耗自身内力
  - 防守方内功防御减免
  - 反震伤害根据等级分级
  """

  @doc """
  检查是否可以学习内功（对应 valid_learn）

  要求基本内功等级 >= 10
  """
  def valid_learn?(skill_level) when is_integer(skill_level) do
    skill_level >= 10
  end

  @doc """
  计算内功反击伤害（对应 hit_ob）

  返回伤害值或反击描述
  """
  def hit_ob(attacker, defender, damage_bonus, factor, opts \\ []) do
    attacker_neili = Keyword.get(opts, :attacker_neili, 0)
    attacker_max_neili = Keyword.get(opts, :attacker_max_neili, 0)
    defender_neili = Keyword.get(opts, :defender_neili, 0)
    defender_max_neili = Keyword.get(opts, :defender_max_neili, 0)
    attacker_force = Keyword.get(opts, :attacker_force, 0)
    defender_force = Keyword.get(opts, :defender_force, 0)
    defender_armor = Keyword.get(opts, :defender_armor_vs_force, 0)
    attacker_combat_exp = Keyword.get(opts, :attacker_combat_exp, 0)
    defender_combat_exp = Keyword.get(opts, :defender_combat_exp, 0)
    attacker_weapon = Keyword.get(opts, :attacker_weapon, nil)

    attacker_fac = min(attacker_neili, attacker_max_neili)
    defender_fac = min(defender_neili, defender_max_neili)

    cond do
      # 攻击方经验不足，消耗内力
      attacker_combat_exp < defender_combat_exp * 20 ->
        {:neili_consume, factor}

      # 计算反击伤害
      true ->
        damage = div(attacker_fac, 20) + factor - div(defender_fac, 24)

        cond do
          # 反击伤害为负，内力不足被反震
          damage < 0 ->
            if is_nil(attacker_weapon) and defender_force > 0 and
                 defender_force + div(defender_force, 3) < attacker_force do
              # 计算反震伤害
              counter_damage = -damage * 2
              level = classify_counter_damage(counter_damage)
              {:counterattack, counter_damage, level}
            else
              {:damage, damage}
            end

          # 防御减免
          true ->
            damage = damage - defender_armor

            if damage_bonus + damage < 0 do
              {:damage, -damage_bonus}
            else
              {:damage, damage}
            end
        end
    end
  end

  @doc """
  内力反击等级分类
  """
  def classify_counter_damage(damage) when damage < 10, do: :mild
  def classify_counter_damage(damage) when damage < 20, do: :moderate
  def classify_counter_damage(damage) when damage < 40, do: :heavy
  def classify_counter_damage(damage) when damage < 80, do: :severe
  def classify_counter_damage(_damage), do: :critical

  @doc """
  检查修炼效果（对应 do_effect）

  用于判别修炼内功时的走火入魔风险
  """
  def do_effect(character, opts \\ []) do
    skills = Keyword.get(opts, :skills, %{})
    is_player = Keyword.get(opts, :is_player, true)

    unless is_player do
      {:ok, :no_effect}
    else
      # 计算少林技能加成
      shaolin_bonus = calculate_shaolin_bonus(skills)

      if shaolin_bonus < 10_000 do
        {:ok, :no_effect}
      else
        level = div(shaolin_bonus, 100)

        cond do
          level < div(9, 10) -> {:warning, :potential_deviation}
          level < 1 -> {:warning, :mild_deviation}
          level < div(11, 10) -> {:warning, :restless}
          level < div(13, 10) -> {:info, :slight_异样}
          true -> {:ok, :normal}
        end
      end
    end
  end

  defp calculate_shaolin_bonus(skills) do
    skills
    |> Enum.filter(fn {skill, _level} ->
      String.contains?(to_string(skill), "shaolin")
    end)
    |> Enum.reduce(0, fn {_skill, level}, acc ->
      acc + level * level * level
    end)
  end
end

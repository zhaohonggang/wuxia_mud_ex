defmodule ExKantele.Combat.CombatDaemon do
  @moduledoc """
  对应原文件: lpc_example/daemon/daemon_combatd.c (战斗守护, 79280B / 2295 行)

  迁移判定: C —— **框架核心战斗引擎**，绝非单文件世界数据。
  它对应 Kalevala 已有的 Kantele.Combat.Engine + Messages。
  正确姿势：不搬 combatd.c 的交互胶水，而是把其中的**数值公式**提炼为
  纯函数并并入引擎。本模块即这些公式的可测落地。

  移植公式（均忠实于原文 do_attack / do_damage / skill_power）:
    - valid_power/1      combat_exp -> 幂次（三段封顶）
    - skill_power/5      技能/经验/属性合成攻击或防御幂
    - dodge?/2, parry?/2 命中判定: A/(A+B)
    - base_damage/1      基础伤害随机化
    - damage_bonus/1      心狠手辣加成
    - str_bonus/1, int_bonus/1  属性加成
    - damage_cap/2, wound_cap/2 大额伤害/伤口封顶
  """

  # 原 EXP_LIMIT = 200000（技能提升经验底线，见 FRAMEWORK_REQUIREMENTS.md）

  @doc """
  valid_power：combat_exp -> 参与 A/(A+B) 的幂次。
  原文三段：
    < 200万       -> 原值
    200~300万     -> 200万 + (exp-200万)/10
    >= 300万      -> 300万 + (exp-300万)/20
  """
  def valid_power(exp) when exp < 2_000_000, do: exp

  def valid_power(exp) when exp < 3_000_000 do
    exp = exp - 2_000_000
    2_000_000 + div(exp, 10)
  end

  def valid_power(exp), do: 3_000_000 + div(exp - 3_000_000, 20)

  @doc """
  skill_power：合成攻击/防御幂。
  opts: %{level, combat_exp, str | dex, temp_str | temp_dex, fight_bonus}
  usage: :attack | :defense
  Returns non-negative integer power.
  """
  def skill_power(level, exp, usage, opts \\ %{}) do
    apply_bonus = Map.get(opts, :apply, 0)
    level = level + apply_bonus
    delta = Map.get(opts, :delta, 0)
    level = level + delta

    base_pow = valid_power(exp)

    if level < 1 do
      # 无技能：以经验为主，attack 乘 str / defense 乘 dex
      power = div(base_pow, 2)
      stat = Map.get(opts, if(usage == :attack, do: :str, else: :dex), 0)
      div(power, 30) * stat
    else
      power =
        if level > 500 do
          div(level, 10) * level * level
        else
          div(level * level * level, 10)
        end

      power = power + base_pow

      if usage == :attack do
        str = Map.get(opts, :str, 0) + Map.get(opts, :temp_str, 0)
        power = div(power, 30) * str
        power + div(power, 100) * Map.get(opts, :fight_bonus, 0)
      else
        dex = Map.get(opts, :dex, 0) + Map.get(opts, :temp_dex, 0)
        power = div(power, 30) * dex
        power + div(power, 100) * Map.get(opts, :fight_bonus, 0)
      end
    end
  end

  @doc """
  dodge? / 命中判定(闪避)：random(ap+dp) < dp 则闪开。
  random/1 以 0 起；统一用 :rand.uniform(n) 的 1..n，为忠实原文，
  取 <= dp 判定。rng 供测试（返回 1..ap+dp）。
  Returns true=被闪避, false=命中(可能招架)
  """
  def dodge?(ap, dp, rng \\ &:rand.uniform/1) do
    rng.(ap + dp) <= dp
  end

  @doc """
  parry? / 招架判定：random(ap+pp) < pp，同上取 <= pp。
  """
  def parry?(ap, pp, rng \\ &:rand.uniform/1) do
    rng.(ap + pp) <= pp
  end

  @doc """
  招架修正量 delta：空手对兵刃 / 兵刃对空手。
  原文 do_attack: 对方有武器而我空手 delta=+10；对方空手而我持刃 delta=-10。
  attacker_weapon?: 我是否有武器
  Returns delta
  """
  def parry_delta(attacker_weapon?, victim_weapon?) do
    cond do
      victim_weapon? and not attacker_weapon? -> 10
      attacker_weapon? and not victim_weapon? -> -10
      true -> 0
    end
  end

  @doc """
  base_damage：基础伤害随机化 (damage + random(damage)) / 2
  """
  def base_damage(damage, rng \\ &:rand.uniform/1), do: div(damage + rng.(damage + 1) - 1, 2)

  @doc "基础伤害附加：action.damage * damage / 100"
  def damage_pct(damage, pct), do: damage + div(damage * pct, 100)

  @doc """
  伤害加成：心狠手辣 +20%
  """
  def vicious_bonus(damage), do: damage + div(damage * 20, 100)

  @doc """
  str_bonus：力量对伤害的加成率（分子/分母）。
  do_attack 版：str1 = str*2 + query_str + random(temp_str/2)
  Returns 乘数（damage += damage * str1 / denom）
  """
  def str_bonus(str_combined) do
    # 原文：damage += damage * str1 / 300（do_attack 版本）
    {str_combined, 300}
  end

  @doc """
  int_bonus：智力对伤害的加成（random(int)>8 时生效）。
  Returns ratio: damage += damage * 10/int | 7/int | 4/int
  """
  def int_ratio(int, rng \\ &:rand.uniform/1) when is_integer(int) and int >= 1 do
    if rng.(int) > 8 do
      cond do
        int < 16 -> div(10, int)
        int < 40 -> div(7, int)
        true -> div(4, int)
      end
    else
      0
    end
  end

  @doc """
  damage_cap：大额伤害封顶（do_attack 版 400/200）。
    >400: (d-400)/4 + 300；>200: (d-200)/2 + 200；否则原值
  """
  def damage_cap(d) when d > 400, do: div(d - 400, 4) + 300
  def damage_cap(d) when d > 200, do: div(d - 200, 2) + 200
  def damage_cap(d), do: d

  @doc """
  wound_cap：伤口封顶（同 damage_cap 400/200），且 <1 归 0。
  """
  def wound_cap(d) when d > 400, do: div(d - 400, 4) + 300
  def wound_cap(d) when d > 200, do: div(d - 200, 2) + 200
  def wound_cap(d) when d < 1, do: 0
  def wound_cap(d), do: d

  @doc """
  光明磊落：伤口 -20%
  """
  def righteous_wound(w), do: w - div(w * 20, 100)

  @doc """
  con 效果：伤口 -= 伤口 * (con-10)/100
  """
  def con_wound(w, con), do: w - div(w * (con - 10), 100)
end

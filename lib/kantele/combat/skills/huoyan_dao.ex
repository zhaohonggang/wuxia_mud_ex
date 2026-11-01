defmodule Kantele.Combat.Skills.HuoyanDao do
  @moduledoc """
  火焰刀（对照 `kungfu/skill/huoyan-dao.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/huoyan_dao/`。

  **已迁移**：`valid_learn/2` 门槛（LPC 要求空手、con>=32、shen<=-lvl*1000、max_neili>=1200、
  force>=150、strike>=huoyan-dao）—— 已实现 `valid_learn(stats, character)` 逐条门槛；
  `practice_cost()` = `%{qi: 55, neili: 60}`（LPC receive_damage qi55，base cost lvl/5+60，
  practice_cost/0 无等级参数故取 lvl=0 基准）。

  差异（TODO(migrate)）：
  - 招式表与 `practice_skill` 实际扣减未建模（`practice_cost` 仅作练习门槛）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill


  @actions [
    %{
      "action" => "$N使出一招「钻木取火」，飞身急转，双掌向前平平拍向$n",
      "force" => 90,
      "attack" => 25,
      "dodge" => 15,
      "parry" => 25,
      "damage" => 40,
      "lvl" => 0,
      "skill_name" => "钻木取火"
    },
    %{
      "action" => "$N使出一招「祝融怀焰」，手掌如刀，斜斜劈向$n的$l",
      "force" => 130,
      "attack" => 47,
      "dodge" => 25,
      "parry" => 31,
      "damage" => 55,
      "lvl" => 30,
      "skill_name" => "祝融怀焰"
    },
    %{
      "action" => "$N使出一招「风火无边」，双掌一拍，一道内力自掌中攻向$n的$l",
      "force" => 180,
      "attack" => 61,
      "dodge" => 25,
      "parry" => 40,
      "damage" => 65,
      "lvl" => 60,
      "skill_name" => "风火无边"
    },
    %{
      "action" => "$N使出一招「六道轮回」，双手合十，当头劈向$n",
      "force" => 240,
      "attack" => 75,
      "dodge" => 20,
      "parry" => 47,
      "damage" => 70,
      "lvl" => 90,
      "skill_name" => "六道轮回"
    },
    %{
      "action" => "$N使出一招「双龙吐焰」，双掌一错，两道内力交叉攻向$n的$l",
      "force" => 300,
      "attack" => 80,
      "dodge" => 30,
      "parry" => 56,
      "damage" => 80,
      "lvl" => 120,
      "skill_name" => "双龙吐焰"
    },
    %{
      "action" => "$N使出一招「刀山火海」，双掌向下斜拍，顿时万千道内力从四面八方攻向$n",
      "force" => 350,
      "attack" => 91,
      "dodge" => 35,
      "parry" => 62,
      "damage" => 85,
      "lvl" => 140,
      "skill_name" => "刀山火海"
    },
    %{
      "action" => "$N使出一招「白佛光度」，左臂回收，右掌引内力直刺$n的$l",
      "force" => 370,
      "attack" => 102,
      "dodge" => 37,
      "parry" => 78,
      "damage" => 90,
      "lvl" => 160,
      "skill_name" => "白佛光度"
    },
    %{
      "action" => "$N使出一招「火内莲花」，双掌微并，两臂前伸，一道内劲如排山倒海般攻向$n",
      "force" => 400,
      "attack" => 110,
      "dodge" => 45,
      "parry" => 84,
      "damage" => 109,
      "lvl" => 180,
      "skill_name" => "火内莲花"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 火焰刀之极意",
    "lvl" => 250,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "huoyan-dao"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  @impl true
  # LPC valid_learn(object me)：空手 + con>=32 + shen<=-lvl*1000（正邪值足够邪恶）
  #   + max_neili>=1200 + force>=150 + strike>=huoyan-dao。
  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

  defp shen_of(%{meta: %{stats: %{shen: shen}}}) when is_integer(shen), do: shen
  defp shen_of(_), do: 0

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    shen = shen_of(character)

    cond do
      Skill.wielding?(character) or Skill.secondary_wielding?(character) ->
        {:error, "练火焰刀必须空手。\n"}

      Stats.con(stats) < 32 ->
        {:error, "你的先天根骨孱弱，难以修炼火焰刀。\n"}

      shen > -lvl * 1000 ->
        {:error, "你的杀气不够，难以领悟更高深的火焰刀。\n"}

      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法火候有限，无法领会更高深的火焰刀法。\n"}

      true ->
        :ok
    end
  end

  @doc "练习消耗：LPC practice_skill 扣 qi 55 / neili (lvl/5+60)。practice_cost/0 无
  等级参数，此处取 lvl=0 基准值 %{qi: 55, neili: 60}。"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Skill.pick_action_with_ultimate(
      @actions,
      level,
      attacker,
      @ultimate,
      &ultimate_values/2,
      rng
    )
  end

  @impl true
  def perform_list() do
    %{
      "fen" => Kantele.Combat.Skills.Performs.HuoyanDao.Fen,
      "yan" => Kantele.Combat.Skills.Performs.HuoyanDao.Yan
    }
  end
  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    strike = Skill.skill_of(attacker, "strike")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(strike, 4) + r.(div(strike, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end

defmodule Kantele.Combat.Skills.HuoyanDao do
  @moduledoc """
  火焰刀（对照 `kungfu/skill/huoyan-dao.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/huoyan_dao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、con>=32、shen 与 max_neili>=1200、
    strike>=huoyan-dao，本版以 force>=150 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


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
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

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

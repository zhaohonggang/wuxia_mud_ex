defmodule Kantele.Combat.Skills.HuifengJian do
  @moduledoc """
  回风拂柳剑法（对照 `kungfu/skill/huifeng-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/huifeng_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1200，本版以 force>=100 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N剑尖剑芒暴长，一招「清风袭月」，手中$w自左下大开大阖，一剑\n向右上向$n的$l",
      "force" => 125,
      "attack" => 23,
      "dodge" => 5,
      "damage" => 42,
      "lvl" => 0,
      "skill_name" => "清风袭月"
    },
    %{
      "action" => "$N长剑圈转，施一招「飘雪穿云」，手中$w平展下刺，一剑轻轻划过\n$n的$l",
      "force" => 172,
      "attack" => 31,
      "dodge" => 10,
      "damage" => 59,
      "lvl" => 20,
      "skill_name" => "飘雪穿云"
    },
    %{
      "action" => "只见$N长剑轻灵跳动，剑随身长，右手$w猛地使出一式「千峰竞秀」\n刺向$n的$l",
      "force" => 185,
      "attack" => 39,
      "dodge" => 10,
      "damage" => 73,
      "lvl" => 40,
      "skill_name" => "千峰竞秀"
    },
    %{
      "action" => "$N长剑下指，剑意流转，一招「万流归宗」直取$n的$l",
      "force" => 197,
      "attack" => 45,
      "dodge" => 10,
      "damage" => 75,
      "lvl" => 60,
      "skill_name" => "万流归宗"
    },
    %{
      "action" => "$N剑芒吞吐，幻若灵蛇，手中$w使出一式「乌龙搅柱」，剑势曼妙\n非凡，刺向$n的$l",
      "force" => 212,
      "attack" => 44,
      "dodge" => 10,
      "damage" => 96,
      "lvl" => 90,
      "skill_name" => "乌龙搅柱"
    },
    %{
      "action" => "$N屈腕云剑，剑光如彩碟纷飞，幻出点点星光，右手$w陡然使出那\n式「大雁啼沙」跃跃洒洒飘向$n的$l",
      "force" => 230,
      "attack" => 47,
      "dodge" => 15,
      "damage" => 123,
      "lvl" => 100,
      "skill_name" => "大雁啼沙"
    },
    %{
      "action" => "$N挥剑分击，剑势自胸前跃出，右手$w一式「进退龙游」，毫无留\n恋之势，刺向$n的$l",
      "force" => 250,
      "attack" => 51,
      "dodge" => 15,
      "damage" => 125,
      "lvl" => 110,
      "skill_name" => "进退龙游"
    },
    %{
      "action" => "$N退步，左手剑指划转，腰部一扭，右手$w一记「天地鹤翔」自下\n而上刺向$n的$l",
      "force" => 275,
      "attack" => 65,
      "dodge" => 25,
      "damage" => 130,
      "lvl" => 120,
      "skill_name" => "天地鹤翔"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 回风拂柳剑之极意",
    "lvl" => 200,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "huifeng-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 huifeng-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为不够。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法火候太浅。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的回风拂柳剑。\n"}

      true ->
        :ok
    end
  end

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
      "jue" => Kantele.Combat.Skills.Performs.HuifengJian.Jue,
      "mie" => Kantele.Combat.Skills.Performs.HuifengJian.Mie
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    sword = Skill.skill_of(attacker, "sword")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(sword, 4) + r.(div(sword, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end

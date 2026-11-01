defmodule Kantele.Combat.Skills.RuanhongZhusuo do
  @moduledoc """
  软红爪锁（对照 `kungfu/skill/ruanhong-zhusuo.c`）

  鞭/爪法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/ruanhong_zhusuo/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=150 / whip>=100 / whip>=self）与练招消耗
  `practice_cost`（qi 75 / neili 85）已按 LPC 迁移（2026-10-30）。须持鞭检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N端坐不动，一式「天蛛盘丝」，手腕力抬，$w滚动飞舞，宛如灵蛇乱颤扫向$n",
      "force" => 98,
      "attack" => 41,
      "dodge" => -5,
      "parry" => 15,
      "damage" => 32,
      "lvl" => 0
    },
    %{
      "action" => "$N一式「蛛丝马迹」，$w抖得笔直，“呲呲”破空声中向$n疾刺而去",
      "force" => 187,
      "attack" => 48,
      "dodge" => -20,
      "parry" => 36,
      "damage" => 47,
      "lvl" => 80
    },
    %{
      "action" => "$N内劲到处，将$w抖动转成两个圆圈，一式「灵蛛夺食」，从半空中往$n缠下",
      "force" => 231,
      "attack" => 65,
      "dodge" => -10,
      "parry" => 55,
      "damage" => 93,
      "lvl" => 100
    },
    %{
      "action" => "$N劲走螺旋，一式「蛛网织天」，$w在$n眼前连变数种招式，忽然从$l处倒卷上来",
      "force" => 263,
      "attack" => 70,
      "dodge" => 5,
      "parry" => 60,
      "damage" => 102,
      "lvl" => 120
    },
    %{
      "action" => "$N一声高喝，使出「龙蛛捉蟒」，$w急速转动，鞭影纵横，似真似幻，绞向$n",
      "force" => 301,
      "attack" => 77,
      "dodge" => 6,
      "parry" => 65,
      "damage" => 121,
      "lvl" => 140
    },
    %{
      "action" => "$N含胸拔背，一式「金蛛银索」，力道灵动威猛，劲力从四面八方向$n挤压出去",
      "force" => 331,
      "attack" => 85,
      "dodge" => 12,
      "parry" => 70,
      "damage" => 142,
      "lvl" => 160
    },
    %{
      "action" => "$N力贯鞭梢，一招「天虹密布」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 373,
      "attack" => 91,
      "dodge" => 17,
      "parry" => 75,
      "damage" => 163,
      "lvl" => 180
    },
    %{
      "action" => "$N力贯鞭梢，一招「天地蚕食」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 401,
      "attack" => 98,
      "dodge" => 20,
      "parry" => 85,
      "damage" => 189,
      "lvl" => 200
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 软红蛛索之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "ruanhong-zhusuo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 85}

  # LPC `valid_learn(object me)`（源 ruanhong-zhusuo.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练软红蛛索。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不足，没有办法练软红蛛索，多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅，没有办法练软红蛛索。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练软红蛛索。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的软红蛛索。\n"}

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
      "bohu" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Bohu,
      "pan" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Pan,
      "suo" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Suo,
      "teng" => Kantele.Combat.Skills.Performs.RuanhongZhusuo.Teng
    }
  end
  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    whip = Skill.skill_of(attacker, "whip")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(whip, 4) + r.(div(whip, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end

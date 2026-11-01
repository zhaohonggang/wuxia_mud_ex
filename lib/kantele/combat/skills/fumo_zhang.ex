defmodule Kantele.Combat.Skills.FumoZhang do
  @moduledoc """
  二十四路伏魔杖（对照 `kungfu/skill/fumo-zhang.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fumo_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=800，本版以 force>=90 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N纵步上前，手中$w自下而上，沉猛无比地向$n的小腹挑去",
      "force" => 68,
      "attack" => 24,
      "dodge" => -10,
      "parry" => 10,
      "damage" => 15,
      "lvl" => 0
    },
    %{
      "action" => "$N快步跨出，左手平托$w，右掌猛推杖端，顶向$n的胸口",
      "force" => 80,
      "attack" => 36,
      "dodge" => -10,
      "parry" => 19,
      "damage" => 25,
      "lvl" => 30
    },
    %{
      "action" => "$N高举$w，全身跃起，手中$w朝着$n头盖天灵盖猛然击落下去",
      "force" => 93,
      "attack" => 42,
      "dodge" => -5,
      "parry" => 25,
      "damage" => 25,
      "lvl" => 60
    },
    %{
      "action" => "$N双手持杖如橹，对准$n猛地一搅，如同平地刮起一阵旋风",
      "force" => 107,
      "attack" => 51,
      "dodge" => -5,
      "parry" => 30,
      "damage" => 35,
      "lvl" => 80
    },
    %{
      "action" => "$N横持$w，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 120,
      "attack" => 64,
      "dodge" => -15,
      "parry" => 40,
      "damage" => 30,
      "lvl" => 100
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，化出漫天杖影，杖影把$n裹了起来",
      "force" => 150,
      "attack" => 68,
      "dodge" => 5,
      "parry" => 42,
      "damage" => 35,
      "lvl" => 120
    },
    %{
      "action" => "$N双手和十，躬身一递出$w，只见$w自肘弯飞出，拦腰向$n撞去",
      "force" => 180,
      "attack" => 70,
      "dodge" => -5,
      "parry" => 52,
      "damage" => 40,
      "lvl" => 140
    },
    %{
      "action" => "$N大喝一声，手中$w如飞龙般自掌中跃出，直向$n的胸口穿入",
      "force" => 210,
      "attack" => 72,
      "dodge" => -5,
      "parry" => 60,
      "damage" => 45,
      "lvl" => 160
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 伏魔杖之极意",
    "lvl" => 200,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "fumo-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fumo-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力修为不足，无法学习二十四路伏魔杖。\n"}

      Stats.skill(stats, "force") < 90 ->
        {:error, "你的内功火候太浅，无法学习二十四路伏魔杖。\n"}

      Stats.skill(stats, "staff") < 30 ->
        {:error, "你的基本杖法太浅，无法学习二十四路伏魔杖。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的二十四路伏魔杖。\n"}

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
    %{"lun" => Kantele.Combat.Skills.Performs.FumoZhang.Lun}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    staff = Skill.skill_of(attacker, "staff")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(staff, 4) + r.(div(staff, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end

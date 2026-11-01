defmodule Kantele.Combat.Skills.RiyueLun do
  @moduledoc """
  日月轮法（对照 `kungfu/skill/riyue-lun.c`）

  轮/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/riyue_lun/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=1000 门槛本版以 force>=150 代理
    （引擎 `valid_learn/1` 只拿 stats，无 vitals）；
  - LPC 招式表与 `practice_skill` 未建模（`query_action` 返回空、
    `practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N使一招「破竹势」，抡起手中的$w向$n的$l砸去",
      "force" => 120,
      "attack" => 27,
      "dodge" => -10,
      "parry" => 40,
      "damage" => 62,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使一招「隐山谷势」，双肩一沉，舞动手中$w向$n的$l横扫",
      "force" => 160,
      "attack" => 38,
      "dodge" => -20,
      "parry" => 45,
      "damage" => 66,
      "lvl" => 35,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使一招「隐微势」，就地一滚，手中自下而上撩向$n的$l",
      "force" => 200,
      "attack" => 43,
      "dodge" => -20,
      "parry" => 47,
      "damage" => 70,
      "lvl" => 70,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使一招「擒纵势」，身形起伏之际$w扫向$n的$l",
      "force" => 240,
      "attack" => 51,
      "dodge" => 5,
      "parry" => 50,
      "damage" => 75,
      "lvl" => 100,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使一招「圆满势」，$w如离弦之箭般直捣$n的$l",
      "force" => 280,
      "attack" => 55,
      "dodge" => -10,
      "parry" => 55,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N跃入半空，使一招「月重辉势」，高举$w敲向$n的$l",
      "force" => 320,
      "attack" => 61,
      "dodge" => 10,
      "parry" => 60,
      "damage" => 85,
      "lvl" => 140,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使一招「捉月势」，斜举手中$w击向$n的$l",
      "force" => 360,
      "attack" => 65,
      "dodge" => -15,
      "parry" => 68,
      "damage" => 95,
      "lvl" => 150,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N提一口真气，使出「显吉祥」，$w扫向$n的头部",
      "force" => 400,
      "attack" => 70,
      "dodge" => -20,
      "parry" => 75,
      "damage" => 110,
      "lvl" => 160,
      "damage_type" => "挫伤"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 日月轮法之极意",
    "lvl" => 200,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "riyue-lun"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 riyue-lun.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.str(stats) < 32 ->
        {:error, "你先天膂力不足，难以修炼日月轮法。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "hammer") < 100 ->
        {:error, "你的基本锤法不够，难以修炼日月轮法。\n"}

      Stats.skill(stats, "hammer") < lvl ->
        {:error, "你的基本锤法水平有限，无法领会更高深的日月轮法。\n"}

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
      "lian" => Kantele.Combat.Skills.Performs.RiyueLun.Lian,
      "po" => Kantele.Combat.Skills.Performs.RiyueLun.Po,
      "yuan" => Kantele.Combat.Skills.Performs.RiyueLun.Yuan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    hammer = Skill.skill_of(attacker, "hammer")
    parry = Skill.skill_of(attacker, "parry")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(hammer, 4) + r.(div(hammer, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end

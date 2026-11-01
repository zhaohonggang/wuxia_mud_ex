defmodule Kantele.Combat.Skills.SanwuShou do
  @moduledoc """
  散手（对照 `kungfu/skill/sanwu-shou.c`）

  鞭/手法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sanwu_shou/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：max_neili>=800 / force>=120 / whip>=100 / whip>=sanwu-shou；
  - LPC 首门「性格须为『心狠手辣』或『国士无双』」为 alignment 门，本仓未建模
    （无 alignment 字段/设定入口），**未迁移**；
  - LPC 的「须持鞭（`skill_type=="whip"`）」检查由 practice 流程把关，未写入 `valid_learn`；
  - LPC `practice_skill` 已迁移：qi 55 / neili 60；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N单手一扬，一招「无孔不入」，手中$w抖得笔直，对准$n当头罩下",
      "force" => 90,
      "attack" => 13,
      "dodge" => 10,
      "parry" => 10,
      "damage" => 20,
      "lvl" => 0,
      "skill_name" => "无孔不入"
    },
    %{
      "action" => "$N身形一转，一招「无所不至」，手中$w如矫龙般腾空一卷，猛地击向$n",
      "force" => 130,
      "attack" => 24,
      "dodge" => 28,
      "parry" => 15,
      "damage" => 36,
      "lvl" => 30,
      "skill_name" => "无所不至"
    },
    %{
      "action" => "$N唰的一抖长鞭，一招「无所不为」，手中$w抖得笔直，刺向$n$l",
      "force" => 170,
      "attack" => 35,
      "dodge" => 36,
      "parry" => 21,
      "damage" => 55,
      "lvl" => 60,
      "skill_name" => "无所不为"
    },
    %{
      "action" => "$N力贯鞭梢，一招「风起云涌」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 200,
      "attack" => 40,
      "dodge" => 50,
      "parry" => 30,
      "damage" => 64,
      "lvl" => 90,
      "skill_name" => "风起云涌"
    },
    %{
      "action" => "$N运气于腕，一招「风卷残云」，手中$w向一根铜棍般直击向$n",
      "force" => 220,
      "attack" => 50,
      "dodge" => 66,
      "parry" => 38,
      "damage" => 80,
      "lvl" => 120,
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N单臂一挥，一招「欲擒故纵」，手中$w直击向$n腰肋",
      "force" => 260,
      "attack" => 56,
      "dodge" => 80,
      "parry" => 32,
      "damage" => 98,
      "lvl" => 150,
      "skill_name" => "欲擒故纵"
    },
    %{
      "action" => "$N高高跃起，一招「无影无踪」，手中$w笔直向$n当头罩下",
      "force" => 300,
      "attack" => 70,
      "dodge" => 110,
      "parry" => 40,
      "damage" => 130,
      "lvl" => 200,
      "skill_name" => "无影无踪"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 三无三不手之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "sanwu-shou"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 60（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 60}

  # LPC `valid_learn(object me)`（源 sanwu-shou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练三无三不手。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力不足，没有办法练三无三不手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，没有办法练三无三不手。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练三无三不手。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的没有办法练三无三不手。\n"}

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
      "kong" => Kantele.Combat.Skills.Performs.SanwuShou.Kong,
      "wei" => Kantele.Combat.Skills.Performs.SanwuShou.Wei,
      "zhi" => Kantele.Combat.Skills.Performs.SanwuShou.Zhi
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

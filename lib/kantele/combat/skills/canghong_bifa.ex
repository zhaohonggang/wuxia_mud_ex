defmodule Kantele.Combat.Skills.CanghongBifa do
  @moduledoc """
  沧虹笔法（对照 `kungfu/skill/canghong-bifa.c`）

  笔/匕首法载体：`valid_enable("dagger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/canghong_bifa/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / force>=100 / dagger>=30 / dagger>=canghong-bifa）与
  练招消耗 `practice_cost`（LPC 扣 qi 65 / neili 62，须持短兵）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持短兵（weapon skill_type=="dagger"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N吐气开声一招「泣」字诀，$w如灵蛇吞吐，向$n白海穴戳去",
      "force" => 130,
      "attack" => 30,
      "dodge" => -10,
      "parry" => 30,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "泣字诀"
    },
    %{
      "action" => "$N向前跨上一步，混身充满战意，使出「惊」字诀，疾点$n的地仓穴",
      "force" => 170,
      "attack" => 40,
      "dodge" => 5,
      "parry" => 32,
      "damage" => 35,
      "lvl" => 30,
      "skill_name" => "惊字诀"
    },
    %{
      "action" => "$N手中的$w自左而右地一晃，使出「伤」字诀横打$n的章门穴",
      "force" => 190,
      "attack" => 50,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 40,
      "lvl" => 60,
      "skill_name" => "伤字诀"
    },
    %{
      "action" => "$N飞身跃起，一式「卷」字诀，卷起漫天笔影，$w向$n电射而去",
      "force" => 240,
      "attack" => 60,
      "dodge" => 10,
      "parry" => 45,
      "damage" => 50,
      "lvl" => 90,
      "skill_name" => "卷字诀"
    },
    %{
      "action" => "$N凝气守中，$w逼出尺许雪亮笔锋，陡然挥出「离」字诀攻向$n",
      "force" => 260,
      "attack" => 65,
      "dodge" => 5,
      "parry" => 50,
      "damage" => 60,
      "lvl" => 120,
      "skill_name" => "离字诀"
    },
    %{
      "action" => "$N使出一招「悲」字诀挺笔中宫直进，笔尖颤动，中途忽然转而向上",
      "force" => 280,
      "attack" => 70,
      "dodge" => 5,
      "parry" => 52,
      "damage" => 75,
      "lvl" => 150,
      "skill_name" => "悲字诀"
    },
    %{
      "action" => "$N侧身斜刺一笔，一招「苍」字诀卷带着呼呼笔风，将$n包围紧裹",
      "force" => 310,
      "attack" => 75,
      "dodge" => 5,
      "parry" => 64,
      "damage" => 90,
      "lvl" => 180,
      "skill_name" => "苍字诀"
    }
  ]

  @impl true
  def id(), do: "canghong-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  # LPC valid_learn 要求 max_neili>=500 / force>=100 / dagger>=30 / dagger>=self（须持短兵检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "dagger") < 30 ->
        {:error, "你的基本短兵火候太浅。\n"}

      Stats.skill(stats, "dagger") < Stats.skill(stats, id()) ->
        {:error, "你的基本短兵水平有限，无法领会更高深的苍虹笔法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 65 / neili 62（须持短兵，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 62}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"jing" => Kantele.Combat.Skills.Performs.CanghongBifa.Jing}
  end
  def actions(), do: @actions

end

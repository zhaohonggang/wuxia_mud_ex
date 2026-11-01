defmodule Kantele.Combat.Skills.DachengFosuo do
  @moduledoc """
  大乘佛索（对照 `kungfu/skill/dacheng-fosuo.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/dacheng_fosuo/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / shaolin-xinfa>=80）与
  练招消耗 `practice_cost`（LPC 扣 qi 90 / neili 90，须持鞭）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持鞭（weapon skill_type=="whip"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N将$w抖动成圆，一式「圆转如意」，$w已将$n$l缠住",
      "force" => 300,
      "dodge" => 50,
      "damage" => 100,
      "lvl" => 30,
      "skill_name" => "圆转如意"
    },
    %{
      "action" => "$N的$w在$n身旁连连进击，忽然一招「佛自西来」从$n$l处倒卷上来",
      "force" => 400,
      "dodge" => 50,
      "damage" => 150,
      "lvl" => 60,
      "skill_name" => "佛自西来"
    },
    %{
      "action" => "$N运起少林真气，$w陡然变成笔直，一式「佛坐莲花」，向$n直刺过去",
      "force" => 450,
      "dodge" => 50,
      "damage" => 180,
      "lvl" => 90,
      "skill_name" => "佛坐莲花"
    }
  ]

  @impl true
  def id(), do: "dacheng-fosuo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 90 / neili 90（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 90, neili: 90}

  # LPC `valid_learn(object me)`（源 dacheng-fosuo.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力修为不足，没有办法练大乘佛索。\n"}

      Stats.skill(stats, "shaolin-xinfa") < 80 ->
        {:error, "你的少林心法火候太浅。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练鞭法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"chanrao" => Kantele.Combat.Skills.Performs.DachengFosuo.Chanrao}
  end
  def actions(), do: @actions

end

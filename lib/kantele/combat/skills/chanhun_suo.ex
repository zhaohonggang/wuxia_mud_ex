defmodule Kantele.Combat.Skills.ChanhunSuo do
  @moduledoc """
  缠魂锁法（对照 `kungfu/skill/chanhun-suo.c`）

  鞭/锁法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/chanhun_suo/`。

  学习门槛 `valid_learn/2`（max_neili>=400 / force>=80 / whip>=60 / whip>=chanhun-suo）与
  练招消耗 `practice_cost`（LPC 扣 qi 50 / neili 50，须持鞭）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持鞭（weapon skill_type=="whip"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N单手一扬，一招「虐目」，手中$w抖得笔直，直点$n的双眼",
      "force" => 110,
      "dodge" => 12,
      "parry" => 10,
      "damage" => 35,
      "lvl" => 0,
      "skill_name" => "虐目"
    },
    %{
      "action" => "$N力贯鞭梢，一招「伤肝」，手中$w舞出满天鞭影，横扫$n腰间",
      "force" => 140,
      "dodge" => 17,
      "parry" => 15,
      "damage" => 50,
      "lvl" => 20,
      "skill_name" => "伤肝"
    },
    %{
      "action" => "$N运气于腕，一招「损心」，手中$w向一根铜棍般直击$n胸部",
      "force" => 180,
      "dodge" => 21,
      "parry" => 19,
      "damage" => 43,
      "lvl" => 40,
      "skill_name" => "损心"
    },
    %{
      "action" => "$N单臂一挥，一招「催胆」，手中$w直击向$n腰肋",
      "force" => 215,
      "dodge" => 32,
      "parry" => 27,
      "damage" => 58,
      "lvl" => 60,
      "skill_name" => "催胆"
    },
    %{
      "action" => "$N高高跃起，一招「摄魄」，手中$w笔直向$n当头罩下",
      "force" => 255,
      "dodge" => 42,
      "parry" => 37,
      "damage" => 75,
      "lvl" => 80,
      "skill_name" => "摄魄"
    },
    %{
      "action" => "$N身形一转，一招「收魂」，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 330,
      "dodge" => 87,
      "parry" => 69,
      "damage" => 81,
      "lvl" => 100,
      "skill_name" => "收魂"
    }
  ]

  @impl true
  def id(), do: "chanhun-suo"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 50（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 50}

  # LPC `valid_learn(object me)`（源 chanhun-suo.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练习缠魂索。\n"}

      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你的内力不足，没有办法练习缠魂索。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "whip") < 60 ->
        {:error, "你的基本鞭法火候太浅。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的缠魂索。\n"}

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
    %{
      "duo" => Kantele.Combat.Skills.Performs.ChanhunSuo.Duo,
      "suo" => Kantele.Combat.Skills.Performs.ChanhunSuo.Suo
    }
  end
  def actions(), do: @actions

end

defmodule Kantele.Combat.Skills.PichenJian do
  @moduledoc """
  辟尘剑法（对照 `kungfu/skill/pichen-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/pichen_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=1000 / force>=100 / sword>=80 / sword>=pichen-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 50 / neili 55，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N剑尖剑芒暴长，一招「碧漾剑」，手中$w大开大阖，剑芒直刺$n的$l",
      "force" => 98,
      "attack" => 13,
      "dodge" => 2,
      "parry" => 3,
      "damage" => 41,
      "lvl" => 0,
      "skill_name" => "碧漾剑"
    },
    %{
      "action" => "$N剑芒吞吐，单手$w一招「傲寒剑」，剑势曼妙，剑光直逼向$n的$l",
      "force" => 132,
      "attack" => 19,
      "dodge" => 3,
      "parry" => 4,
      "damage" => 58,
      "lvl" => 30,
      "skill_name" => "傲寒剑"
    },
    %{
      "action" => "$N一式「刺骨剑」，屈腕云剑，剑光如彩碟纷飞，幻出点点星光飘向$n",
      "force" => 163,
      "attack" => 23,
      "dodge" => 9,
      "parry" => 10,
      "damage" => 77,
      "lvl" => 60,
      "skill_name" => "刺骨剑"
    },
    %{
      "action" => "$N挥剑分击，剑势自胸前跃出，$w一式「惊神剑」，毫无留恋之势，刺向$n",
      "force" => 190,
      "attack" => 31,
      "dodge" => 11,
      "parry" => 13,
      "damage" => 85,
      "lvl" => 100,
      "skill_name" => "惊神剑"
    },
    %{
      "action" => "$N左手剑指划转，腰部一扭，右手$w一记「辟尘剑」自下而上刺向$n的$l",
      "force" => 225,
      "attack" => 35,
      "dodge" => 5,
      "parry" => 7,
      "damage" => 93,
      "lvl" => 150,
      "skill_name" => "辟尘剑"
    }
  ]

  @impl true
  def id(), do: "pichen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=1000 / force>=100 / sword>=80 / sword>=pichen-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力修为不足。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 80 ->
        {:error, "你的基本剑法火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的辟尘剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 55（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 55}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"ao" => Kantele.Combat.Skills.Performs.PichenJian.Ao}
  end
  def actions(), do: @actions

end

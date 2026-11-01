defmodule Kantele.Combat.Skills.QixingJian do
  @moduledoc """
  七星剑法（对照 `kungfu/skill/qixing-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qixing_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / sword>=10 / sword>=qixing-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 35 / neili 33，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N使一式「星辰满天」，手中$w由左至右横扫向向$n的$l",
      "force" => 70,
      "attack" => 10,
      "dodge" => 10,
      "damage" => 13,
      "lvl" => 0,
      "skill_name" => "星辰满天"
    },
    %{
      "action" => "$N踏上一步，「七星聚月」，手中$w盘旋飞舞出一道剑光劈向$n的$l",
      "force" => 74,
      "attack" => 15,
      "dodge" => 20,
      "damage" => 19,
      "lvl" => 10,
      "skill_name" => "七星聚月"
    },
    %{
      "action" => "$N手中$w一抖，一招「偏花七星」，斜斜一剑反腕撩出，攻向$n的$l",
      "force" => 85,
      "attack" => 20,
      "dodge" => 25,
      "damage" => 21,
      "lvl" => 20,
      "skill_name" => "偏花七星"
    },
    %{
      "action" => "$N手中$w连绕数个大圈，一式「星弛电闪」，一道剑光飞向$n的$l",
      "force" => 118,
      "attack" => 25,
      "dodge" => 30,
      "damage" => 28,
      "lvl" => 30,
      "skill_name" => "星弛电闪"
    },
    %{
      "action" => "$N一式「横移北斗」，左手伸展，右手$w挥向$n的$l",
      "force" => 130,
      "attack" => 30,
      "dodge" => 35,
      "damage" => 32,
      "lvl" => 40,
      "skill_name" => "横移北斗"
    },
    %{
      "action" => "$N手中$w斜指苍天，一式「七星汇聚」，对准$n的$l斜斜击出",
      "force" => 150,
      "attack" => 33,
      "dodge" => 45,
      "damage" => 39,
      "lvl" => 50,
      "skill_name" => "七星汇聚"
    },
    %{
      "action" => "$N一式「朝拜天罡」，$w飞斩盘旋，如疾电般射向$n的胸口",
      "force" => 193,
      "attack" => 40,
      "dodge" => 55,
      "damage" => 54,
      "lvl" => 60,
      "skill_name" => "朝拜天罡"
    },
    %{
      "action" => "$N使一式「剑转七星」，手中$w合身疾刺$n的胸口，威不可当",
      "force" => 220,
      "attack" => 45,
      "dodge" => 55,
      "damage" => 63,
      "lvl" => 80,
      "skill_name" => "剑转七星"
    }
  ]

  @impl true
  def id(), do: "qixing-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / sword>=10 / sword>=qixing-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力修为太差，无法学习七星剑法。\n"}

      Stats.skill(stats, "sword") < 10 ->
        {:error, "你的基本剑法修为不够，无法学习七星剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的七星剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 33（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 33}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"xing" => Kantele.Combat.Skills.Performs.QixingJian.Xing}
  end
  def actions(), do: @actions

end

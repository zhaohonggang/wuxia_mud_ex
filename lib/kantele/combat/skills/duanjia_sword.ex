defmodule Kantele.Combat.Skills.DuanjiaSword do
  @moduledoc """
  段家剑（对照 `kungfu/skill/duanjia-sword.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/duanjia_sword/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / duanshi-xinfa>=20 / sword>=duanjia-sword）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 36，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N向前跨上一步，一招「云横秦岭」，手中$w自左向右向$n的$l缓缓划去",
      "force" => 90,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "skill_name" => "云横秦岭"
    },
    %{
      "action" => "$N向上跃起，左手剑诀，右手一抖，$w剑光缦妙如瀑，一式「飞流直下」直刺$n的$l",
      "force" => 120,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 20,
      "skill_name" => "飞流直下"
    },
    %{
      "action" => "$N一招「雪涌兰关」，$w闪起数道寒光，自下而上反挑$n的$l",
      "force" => 140,
      "dodge" => 35,
      "damage" => 30,
      "lvl" => 40,
      "skill_name" => "雪涌兰关"
    },
    %{
      "action" => "$N一招「奇兵突起」，手中$w看似横扫实则斜劈，刺向$n的$l",
      "force" => 160,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 60,
      "skill_name" => "奇兵突起"
    },
    %{
      "action" => "$N使出「夜叉探海」，$w挽出三个剑花，绵绵不断划向$n的$l",
      "force" => 180,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 80,
      "skill_name" => "夜叉探海"
    },
    %{
      "action" => "$N一招「泰山压顶」，左手一捏剑诀，右手$w自上而下雷霆万钧般直向$n的$l劈了下去",
      "force" => 210,
      "dodge" => 15,
      "damage" => 60,
      "lvl" => 100,
      "skill_name" => "泰山压顶"
    },
    %{
      "action" => "$N一招「雨打梨花」，身在半空，$w回抽，反手勾向$n的$l",
      "force" => 240,
      "dodge" => 20,
      "damage" => 65,
      "lvl" => 120,
      "skill_name" => "雨打梨花"
    },
    %{
      "action" => "$N身影一晃, 绕到$n背后，一招「逐鹿中原」，剑尖向$n的$l疾挑",
      "force" => 270,
      "dodge" => 25,
      "damage" => 70,
      "lvl" => 140,
      "skill_name" => "逐鹿中原"
    }
  ]

  @impl true
  def id(), do: "duanjia-sword"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / duanshi-xinfa>=20 / sword>=duanjia-sword（须持剑检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "duanshi-xinfa") < 20 ->
        {:error, "你的段氏心法火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候不够，无法领会更高深的段家剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 36（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 36}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "jing" => Kantele.Combat.Skills.Performs.DuanjiaSword.Jing,
      "jue" => Kantele.Combat.Skills.Performs.DuanjiaSword.Jue
    }
  end
  def actions(), do: @actions

end

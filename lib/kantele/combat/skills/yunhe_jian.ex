defmodule Kantele.Combat.Skills.YunheJian do
  @moduledoc """
  云鹤剑法（对照 `kungfu/skill/yunhe-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/yunhe_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=20 / sword>=30 / sword>=yunhe-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 50 / neili 45，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N剑尖向右，绕身一周，一式「百鹤鸣晓」，$w突然向$n的$l刺去，",
      "force" => 35,
      "attack" => 2,
      "dodge" => -40,
      "parry" => -40,
      "damage" => 3,
      "lvl" => 0,
      "skill_name" => "百鹤鸣晓"
    },
    %{
      "action" => "$N使出一式「仙鹤西来」，身体凌空侧翻，一剑从身下刺出",
      "force" => 59,
      "attack" => 3,
      "dodge" => -35,
      "parry" => -35,
      "damage" => 4,
      "lvl" => 20,
      "skill_name" => "仙鹤西来"
    },
    %{
      "action" => "$N左手剑指血指，右手$w使出一招「乘鹤东归」，由上至下猛向$n的$l劈刺",
      "force" => 77,
      "attack" => 5,
      "dodge" => -23,
      "parry" => -23,
      "damage" => 7,
      "lvl" => 40,
      "skill_name" => "乘鹤东归"
    },
    %{
      "action" => "$N撤步缩身，$w按藏于臂下，一招「一鹤冲宵」，快如闪电般刺向$n的$l",
      "force" => 83,
      "attack" => 9,
      "dodge" => -18,
      "parry" => -18,
      "damage" => 10,
      "lvl" => 60,
      "skill_name" => "一鹤冲宵"
    },
    %{
      "action" => "$N踏步向前，一式「鹤贝相争」，手中长剑摆动，剑尖刺向$n的$l",
      "force" => 127,
      "attack" => 11,
      "dodge" => -9,
      "parry" => -9,
      "damage" => 12,
      "lvl" => 80,
      "skill_name" => "鹤贝相争"
    },
    %{
      "action" => "$N一招「云鹤三舞」，身体背转，手中$w由右肩上方反手向下刺出",
      "force" => 179,
      "attack" => 31,
      "dodge" => -5,
      "parry" => -5,
      "damage" => 44,
      "lvl" => 100,
      "skill_name" => "云鹤三舞"
    },
    %{
      "action" => "$N一式「云鹤七舞」，剑走中锋，气势威严，将$n笼罩于重重剑气之中",
      "force" => 217,
      "attack" => 35,
      "dodge" => 5,
      "parry" => 5,
      "damage" => 56,
      "lvl" => 130,
      "skill_name" => "云鹤七舞"
    },
    %{
      "action" => "$N向前弯身，一招「云鹤九舞」，$w忽然从身下刺出，快如流星闪电",
      "force" => 260,
      "attack" => 48,
      "dodge" => 10,
      "parry" => 10,
      "damage" => 72,
      "lvl" => 160,
      "skill_name" => "云鹤九舞"
    },
    %{
      "action" => "$N横握$w，左右晃动，一招「鹤舞十二天」，剑气直逼$n的腰部要害",
      "force" => 305,
      "attack" => 51,
      "dodge" => 14,
      "parry" => 14,
      "damage" => 84,
      "lvl" => 200,
      "skill_name" => "鹤舞十二天"
    }
  ]

  @impl true
  def id(), do: "yunhe-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / force>=20 / sword>=30 / sword>=yunhe-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 30 ->
        {:error, "你的基本剑法火候太浅，无法修炼云鹤七剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的云鹤七剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 45（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 45}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"chong" => Kantele.Combat.Skills.Performs.YunheJian.Chong}
  end
  def actions(), do: @actions

end

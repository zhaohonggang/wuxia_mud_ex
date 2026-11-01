defmodule Kantele.Combat.Skills.JingangQuan do
  @moduledoc """
  金刚拳（对照 `kungfu/skill/jingang-quan.c`）

  拳法载体：`valid_enable("cuff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jingang_quan/`。

  学习门槛 `valid_learn/2`（force>=30 / max_neili>=100 / cuff>=jingang-quan）与
  练招消耗 `practice_cost`（LPC 扣 qi 59 / neili 58，须空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「须空手（weapon/secondary_weapon）」检查与「cuff/level 低于招式解锁等级」的
  招式表门槛未在 `valid_learn` 建模（空手由 practice 流程把关，招式表沿用基类占位 TODO）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N盘膝而坐，二手合十，一式「莲花座」，双拳蓄势而发，击向$n的$l",
      "force" => 120,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "莲花座"
    },
    %{
      "action" => "$N一式「烈火锥」，双掌轮流下击，拳势如焰，吡啪爆响",
      "force" => 170,
      "dodge" => 15,
      "damage" => 45,
      "lvl" => 40,
      "skill_name" => "烈火锥"
    },
    %{
      "action" => "$N腾空飞起，一式「八方雨」，双手双腿齐出，令$n无可躲藏",
      "force" => 220,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 70,
      "skill_name" => "八方雨"
    },
    %{
      "action" => "$N双掌虚含，掌缘下沉，一式「掌心雷」，缓缓向$n推出",
      "force" => 270,
      "dodge" => 25,
      "damage" => 70,
      "lvl" => 100,
      "skill_name" => "掌心雷"
    },
    %{
      "action" => "$N一臂前伸，一臂后指，一式「五指山」，攻向$n的身前身后",
      "force" => 320,
      "dodge" => 30,
      "damage" => 80,
      "lvl" => 120,
      "skill_name" => "五指山"
    },
    %{
      "action" => "$N一式「观音渡」，两手十指虚点$n的全身三十六道要穴",
      "force" => 340,
      "dodge" => 35,
      "damage" => 85,
      "lvl" => 140,
      "skill_name" => "观音渡"
    },
    %{
      "action" => "$N两目内视，双手内笼，一式「天龙唱」，四面八方响起震人心魄的龙吟",
      "force" => 360,
      "dodge" => 35,
      "damage" => 90,
      "lvl" => 160,
      "skill_name" => "天龙唱"
    },
    %{
      "action" => "$N似笑非笑，双拳无形无定，一式「如来笑」，骤然击向$n的前胸",
      "force" => 395,
      "dodge" => 40,
      "damage" => 100,
      "lvl" => 180,
      "skill_name" => "如来笑"
    }
  ]

  @impl true
  def id(), do: "jingang-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  # LPC valid_learn 要求 force>=30 / max_neili>=100 / cuff>=jingang-quan
  # （空手检查 weapon/secondary_weapon 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 59 / neili 58（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 59, neili: 58}

  # LPC `valid_learn(object me)`（源 jingang-quan.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练大金刚拳必须空手。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，无法学大金刚拳。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练大金刚拳。\n"}

      Stats.skill(stats, "cuff") < lvl ->
        {:error, "你的基本拳法水平有限，无法领会更高深的大金刚拳。\n"}

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
    %{"jingang" => Kantele.Combat.Skills.Performs.JingangQuan.Jingang}
  end
  def actions(), do: @actions

end

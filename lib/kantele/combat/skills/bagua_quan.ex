defmodule Kantele.Combat.Skills.BaguaQuan do
  @moduledoc """
  武学实装「bagua-quan」（源 bagua-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/bagua_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双掌一错，使出「乾字决」，双拳一上一下对准$n的$l连拍三招",
      "force" => 60,
      "attack" => 20,
      "parry" => 5,
      "dodge" => 40,
      "damage" => 4,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "乾字决"
    },
    %{
      "action" => "$N绕着$n一转，满场游走，拳出如风，连绵不绝地击向$n，正是八卦拳中的「坤字决」",
      "force" => 80,
      "attack" => 25,
      "parry" => 6,
      "dodge" => 43,
      "damage" => 7,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "坤字决"
    },
    %{
      "action" => "$N使出一招「巽字决」，左拳虚击$n的前胸，一错身，右拳迅速横扫$n的太阳穴",
      "force" => 100,
      "attack" => 28,
      "parry" => 8,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "巽字决"
    },
    %{
      "action" => "$N使一招「坎字决」左拳击出，不等招式使老，右拳已从左拳之底穿出，对准$n的$l「呼」地一拳",
      "force" => 120,
      "attack" => 35,
      "parry" => 11,
      "dodge" => 47,
      "damage" => 17,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "坎字决"
    },
    %{
      "action" => "$N使出一招「震字决」，身形一低，左手护顶，右手已迅雷不及掩耳的一拳击向$n的裆部",
      "force" => 140,
      "attack" => 40,
      "parry" => 13,
      "dodge" => 49,
      "damage" => 20,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "震字决"
    },
    %{
      "action" => "$N左拳突然张开，拳开变掌，直击化为横扫，一招「兑字决」便往$n的$l招呼过去",
      "force" => 200,
      "attack" => 48,
      "parry" => 18,
      "dodge" => 54,
      "damage" => 28,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "兑字决"
    },
    %{
      "action" => "$N一招「离字决」，顿时幻出重重拳影，气势如虹，铺天盖地袭向$n全身",
      "force" => 280,
      "attack" => 60,
      "parry" => 23,
      "dodge" => 63,
      "damage" => 37,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "离字决"
    },
    %{
      "action" => "$N微微一笑，手捏「艮字决」，飞身跃起，半空中一脚踢向$n面门，却是个虚招。\\n",
      "force" => 290,
      "attack" => 62,
      "parry" => 25,
      "dodge" => 65,
      "damage" => 40,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "艮字决"
    }
  ]

  @impl true
  def id(), do: "bagua-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 40}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end

end

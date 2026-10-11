defmodule Kantele.Combat.Skills.WuduShenzhang do
  @moduledoc """
  武学实装「wudu-shenzhang」（源 wudu-shenzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wudu_shenzhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「斜阳照路」，左掌叠于右掌之上，劈向$n",
      "force" => 80,
      "attack" => 2,
      "parry" => 1,
      "dodge" => 30,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "斜阳照路"
    },
    %{
      "action" => "$N一招「千山鸟飞绝」，面色凝重，双掌轻飘飘地拍向$n",
      "force" => 100,
      "attack" => 8,
      "parry" => 3,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "千山鸟飞绝"
    },
    %{
      "action" => "$N一招「长空明净」，双掌幻化一片掌影，将$n笼罩于内。",
      "force" => 130,
      "attack" => 12,
      "parry" => 4,
      "dodge" => 43,
      "damage" => 35,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "长空明净"
    },
    %{
      "action" => "$N一招「万水千山」，向$n的$l连击数掌",
      "force" => 150,
      "attack" => 15,
      "parry" => 8,
      "dodge" => 55,
      "damage" => 50,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "万水千山"
    },
    %{
      "action" => "$N一招「万径人踪灭」，只见一片掌影攻向$n",
      "force" => 180,
      "attack" => 22,
      "parry" => 0,
      "dodge" => 52,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "万径人踪灭"
    },
    %{
      "action" => "$N双掌平挥，一招「过关斩将」击向$n",
      "force" => 230,
      "attack" => 23,
      "parry" => 11,
      "dodge" => 65,
      "damage" => 50,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "过关斩将"
    },
    %{
      "action" => "$N一招「彩云遮月」，只见一片掌影攻向$n",
      "force" => 260,
      "attack" => 28,
      "parry" => 5,
      "dodge" => 63,
      "damage" => 80,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "彩云遮月"
    },
    %{
      "action" => "$N施出「高山流水」，右手横扫$n的$l，左手攻向$n的胸口",
      "force" => 280,
      "attack" => 25,
      "parry" => 12,
      "dodge" => 77,
      "damage" => 90,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "高山流水"
    },
    %{
      "action" => "$N左掌虚晃，右掌一记「夕阳西下」击向$n的头部",
      "force" => 320,
      "attack" => 31,
      "parry" => 15,
      "dodge" => 80,
      "damage" => 100,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "夕阳西下"
    },
    %{
      "action" => "$N施出「万毒噬体」，双掌同时击向$n的$l",
      "force" => 360,
      "attack" => 32,
      "parry" => 10,
      "dodge" => 81,
      "damage" => 130,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "万毒噬体"
    }
  ]

  @impl true
  def id(), do: "wudu-shenzhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 81, neili: 73}

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


  @impl true
  def perform_list() do
    %{
      "huan" => Kantele.Combat.Skills.Performs.WuduShenzhang.Huan,
      "shi" => Kantele.Combat.Skills.Performs.WuduShenzhang.Shi
    }
  end
end

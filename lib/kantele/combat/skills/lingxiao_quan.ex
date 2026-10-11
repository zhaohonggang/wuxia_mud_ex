defmodule Kantele.Combat.Skills.LingxiaoQuan do
  @moduledoc """
  武学实装「lingxiao-quan」（源 lingxiao-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lingxiao_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N站立如松，一式「冲天」，两股拳风破气而发，击向$n的$l",
      "force" => 40,
      "attack" => 8,
      "parry" => 3,
      "dodge" => 2,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "冲天"
    },
    %{
      "action" => "$N一式「破地」，左拳下击，右拳随后直冲，势如地裂",
      "force" => 55,
      "attack" => 9,
      "parry" => 1,
      "dodge" => 2,
      "damage" => 7,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "破地"
    },
    %{
      "action" => "$N腾空飞起，一式「腾风」，拳式变腿招踢出，$n急忙躲闪",
      "force" => 64,
      "attack" => 12,
      "parry" => 5,
      "dodge" => 3,
      "damage" => 9,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "腾风"
    },
    %{
      "action" => "$N双拳划开，疾风突起，一式「劈海」，向$n发出",
      "force" => 71,
      "attack" => 13,
      "parry" => 4,
      "dodge" => 6,
      "damage" => 11,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "劈海"
    },
    %{
      "action" => "$N两臂后展，拳招变掌，一式「开山」，插向$n的掖下死穴",
      "force" => 84,
      "attack" => 18,
      "parry" => 13,
      "dodge" => 12,
      "damage" => 15,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "开山"
    },
    %{
      "action" => "$N一式「袭火」，拳变指，点向$n的胸前死穴",
      "force" => 93,
      "attack" => 21,
      "parry" => 7,
      "dodge" => 9,
      "damage" => 19,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "袭火"
    },
    %{
      "action" => "$N出其不意，从上而下，一式「碎冰」，四周空气先凝集后突爆开",
      "force" => 101,
      "attack" => 24,
      "parry" => 8,
      "dodge" => 12,
      "damage" => 25,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "碎冰"
    },
    %{
      "action" => "$N眼眉一皱，双拳破气齐发，一式「凌霄总决」，击向$n的头额",
      "force" => 140,
      "attack" => 28,
      "parry" => 13,
      "dodge" => 12,
      "damage" => 27,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "凌霄总决"
    }
  ]

  @impl true
  def id(), do: "lingxiao-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 25}

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
      "jue" => Kantele.Combat.Skills.Performs.LingxiaoQuan.Jue,
      "san" => Kantele.Combat.Skills.Performs.LingxiaoQuan.San
    }
  end
end

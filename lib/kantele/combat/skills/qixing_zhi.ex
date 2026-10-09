defmodule Kantele.Combat.Skills.QixingZhi do
  @moduledoc """
  武学实装「qixing-zhi」（源 qixing-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qixing_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一指点出，这一招「朝拜天罡」中宫直进，指气将$n压得揣不过气来",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "点穴",
      "skill_name" => "朝拜天罡"
    },
    %{
      "action" => "$N身形不动，一招「七星汇聚」攻出。$n稍一犹豫，$N的中指已刺向自己",
      "force" => 140,
      "attack" => 5,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "点穴",
      "skill_name" => "七星汇聚"
    },
    %{
      "action" => "只见$N一转身，正是一式「横移北斗」，一指由胁下穿出，疾刺$n的$l",
      "force" => 155,
      "attack" => 10,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "点穴",
      "skill_name" => "横移北斗"
    },
    %{
      "action" => "只见$N一招「偏花七星」，十指如穿花蝴蝶一般上下翻飞，全全笼罩$n",
      "force" => 170,
      "attack" => 20,
      "parry" => 11,
      "dodge" => 9,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "点穴",
      "skill_name" => "偏花七星"
    },
    %{
      "action" => "只见$N面带微笑，负手而立，一招「彗星飞坠」，$n顿觉一道指力直扑而来",
      "force" => 190,
      "attack" => 30,
      "parry" => 12,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 80,
      "damage_type" => "点穴",
      "skill_name" => "彗星飞坠"
    },
    %{
      "action" => "忽听$N一声轻叱，一招「满天星辰」，左手划了个半弧，食指闪电般点向$n",
      "force" => 250,
      "attack" => 40,
      "parry" => 23,
      "dodge" => 25,
      "damage" => 57,
      "lvl" => 100,
      "damage_type" => "点穴",
      "skill_name" => "满天星辰"
    }
  ]

  @impl true
  def id(), do: "qixing-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

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

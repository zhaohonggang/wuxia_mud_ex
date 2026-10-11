defmodule Kantele.Combat.Skills.SongshanZhang do
  @moduledoc """
  武学实装「songshan-zhang」（源 songshan-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/songshan_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「滚滚长江」，左手斜出，一掌向$n的$l打去",
      "force" => 10,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "滚滚长江"
    },
    %{
      "action" => "$N使一招「大江东去」，右手挥出，劈向$n的$l",
      "force" => 25,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 48,
      "damage" => 0,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "大江东去"
    },
    %{
      "action" => "$N双手回撤，忽地反转，一式「天日无华」，击向$n的$l",
      "force" => 35,
      "attack" => 0,
      "parry" => 45,
      "dodge" => 50,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "天日无华"
    },
    %{
      "action" => "$N双手分开，左右齐出，一招「水火不容」，分击$n的面门和$l",
      "force" => 42,
      "attack" => 0,
      "parry" => 71,
      "dodge" => 44,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "水火不容"
    },
    %{
      "action" => "$N单脚踏出，屈身向前，一式「连绵不绝」，击向$n$l",
      "force" => 50,
      "attack" => 0,
      "parry" => 60,
      "dodge" => 55,
      "damage" => 0,
      "lvl" => 42,
      "damage_type" => "瘀伤",
      "skill_name" => "连绵不绝"
    },
    %{
      "action" => "$N双手猛然回收，突然右掌直出，一式「漫天花雨」向$n的$l打去",
      "force" => 60,
      "attack" => 0,
      "parry" => 62,
      "dodge" => 60,
      "damage" => 0,
      "lvl" => 55,
      "damage_type" => "瘀伤",
      "skill_name" => "漫天花雨"
    },
    %{
      "action" => "$N快步向前，一招「阳光娇子」，左掌直击$n$l",
      "force" => 70,
      "attack" => 0,
      "parry" => 71,
      "dodge" => 54,
      "damage" => 0,
      "lvl" => 65,
      "damage_type" => "瘀伤",
      "skill_name" => "阳光娇子"
    },
    %{
      "action" => "$N掌风凌厉，掌速猛然变快，一式「会心一击」双掌已到$n$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 80,
      "dodge" => 76,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "会心一击"
    }
  ]

  @impl true
  def id(), do: "songshan-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 35}

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
      "po" => Kantele.Combat.Skills.Performs.SongshanZhang.Po
    }
  end
end

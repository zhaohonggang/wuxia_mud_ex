defmodule Kantele.Combat.Skills.RuyingSuixingtui do
  @moduledoc """
  武学实装「ruying-suixingtui」（源 ruying-suixingtui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/ruying_suixingtui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N纵身向前，忽然伸出左腿，一式「仗义执言」，直踢$n的头部",
      "force" => 200,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "仗义执言"
    },
    %{
      "action" => "$N身形一闪，双足点地，一式「七星伴月」，在空中连踢七脚，直本$n的头、胸、臂",
      "force" => 250,
      "attack" => 0,
      "parry" => -10,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "七星伴月"
    },
    %{
      "action" => "$N身体前倾，左脚画圆，右腿使出一式「佛界无边」，扫向$n的腰部",
      "force" => 300,
      "attack" => 0,
      "parry" => 5,
      "dodge" => -10,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "佛界无边"
    },
    %{
      "action" => "$N左足倏地弹出，连环六腿，分踢$n的头部，胸部和裆部，正是一式「转世轮回」",
      "force" => 350,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "转世轮回"
    },
    %{
      "action" => "$N左足独立，右腿随身形反转横扫，一招「西天极乐」，踢向$n的$l",
      "force" => 400,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 0,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "西天极乐"
    },
    %{
      "action" => "$N跃起在半空，双足带起无数劲风，一式「佛祖慈悲」迅捷无伦地卷向$n",
      "force" => 450,
      "attack" => 0,
      "parry" => -10,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "佛祖慈悲"
    }
  ]

  @impl true
  def id(), do: "ruying-suixingtui"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 10}

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

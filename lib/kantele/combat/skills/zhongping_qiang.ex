defmodule Kantele.Combat.Skills.ZhongpingQiang do
  @moduledoc """
  武学实装「zhongping-qiang」（源 zhongping-qiang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhongping_qiang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手一别，尽力前伸，使出一招「中平无敌」，手中$w平平刺向$n",
      "force" => 80,
      "attack" => 10,
      "parry" => 25,
      "dodge" => 3,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "中平无敌"
    },
    %{
      "action" => "$N手中$w盘旋回转，屈身下蹲，反手一招「夜叉探海」自下向$n刺去",
      "force" => 100,
      "attack" => 20,
      "parry" => 25,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "夜叉探海"
    },
    %{
      "action" => "$N高高举起$w，迎空抖出数朵枪花，一招「灵蛇出洞」向$n分心扎去",
      "force" => 110,
      "attack" => 27,
      "parry" => 21,
      "dodge" => 10,
      "damage" => 44,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "灵蛇出洞"
    },
    %{
      "action" => "$N施出「游龙逆转」，手中$w斜刺消去$n的后招，接着闪电般刺向$n",
      "force" => 120,
      "attack" => 30,
      "parry" => 35,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "游龙逆转"
    }
  ]

  @impl true
  def id(), do: "zhongping-qiang"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 20, neili: 20}

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
      "ding" => Kantele.Combat.Skills.Performs.ZhongpingQiang.Ding
    }
  end
end

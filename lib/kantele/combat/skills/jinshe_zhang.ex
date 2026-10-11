defmodule Kantele.Combat.Skills.JinsheZhang do
  @moduledoc """
  武学实装「jinshe-zhang」（源 jinshe-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jinshe_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双掌一错，一招「千蛇出洞」幻出漫天掌影拢向$n的$l",
      "force" => 240,
      "attack" => 31,
      "parry" => 10,
      "dodge" => 30,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "千蛇出洞"
    },
    %{
      "action" => "$N暴喝一声，双掌连环推出，一招「大沼龙蛇」强劲的掌风直扑$n的$l",
      "force" => 240,
      "attack" => 22,
      "parry" => 10,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "魔吼天地"
    },
    %{
      "action" => "$N双掌纷飞，一招「双蛇抢珠」直取$n的$l",
      "force" => 240,
      "attack" => 29,
      "parry" => 30,
      "dodge" => 10,
      "damage" => 45,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "双蛇抢珠"
    },
    %{
      "action" => "$N提气缠身游走，一招「游走式」，森森掌风无孔不入般地击向$n的$l",
      "force" => 240,
      "attack" => 30,
      "parry" => 50,
      "dodge" => 10,
      "damage" => 70,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "游走式"
    },
    %{
      "action" => "$N盘身错步，双掌平推，凝神聚气，一招「盘身式」拍向$n的$l",
      "force" => 210,
      "attack" => 38,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "盘身式"
    },
    %{
      "action" => "$N左掌立于胸前，右掌推出，一招「金蛇吐衅」击向$n$l",
      "force" => 210,
      "attack" => 32,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 51,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "金蛇吐衅"
    },
    %{
      "action" => "$N使出「金蛇翻身咬」，身形凌空飞起，从空中当头向$n的$l出掌攻击",
      "force" => 210,
      "attack" => 25,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 42,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "金蛇翻身咬"
    },
    %{
      "action" => "$N使出一招「杯弓蛇影」，左掌化虚为实击向$n的$l",
      "force" => 210,
      "attack" => 38,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "杯弓蛇影"
    },
    %{
      "action" => "$N左掌画了个圈圈，右掌推出，一招「金蛇缠丝手」击向$n$l",
      "force" => 210,
      "attack" => 28,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 53,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "金蛇缠丝手"
    },
    %{
      "action" => "$N使出「灵蛇游八方」，身形散作八处同时向$n的$l出掌攻击",
      "force" => 210,
      "attack" => 27,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 47,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "灵蛇游八方"
    },
    %{
      "action" => "$N使出金蛇游身掌法「金蛇探头」，如鬼魅般欺至$n身前，一掌拍向$n的$l",
      "force" => 210,
      "attack" => 31,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "金蛇探头"
    },
    %{
      "action" => "$N内气上提，全身拔起，一招「金龙升天」，双掌凌空拍下，$n的全身都被笼罩在掌力之下",
      "force" => 210,
      "attack" => 35,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "金龙升天"
    }
  ]

  @impl true
  def id(), do: "jinshe-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 53}

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
      "fugu" => Kantele.Combat.Skills.Performs.JinsheZhang.Fugu
    }
  end
end

defmodule Kantele.Combat.Skills.DacidabeiShou do
  @moduledoc """
  武学实装「dacidabei-shou」（源 dacidabei-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dacidabei_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「莲花手」，双掌合十，直直撞向$n的前胸",
      "force" => 120,
      "attack" => 70,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "莲花手"
    },
    %{
      "action" => "$N使出一招「观音手」，飞身跃起，双手如勾，抓向$n的$l",
      "force" => 170,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "观音手"
    },
    %{
      "action" => "$N使出一招「佛母手」，运力于指，直取$n的$l",
      "force" => 220,
      "attack" => 60,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "佛母手"
    },
    %{
      "action" => "$N使出一招「红阎婆罗手」，怒吼一声，一掌当头拍向$n的$l",
      "force" => 250,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "红阎婆罗手"
    },
    %{
      "action" => "$N使出一招「慈悲手」，猛冲向前，掌如游龙般攻向$n",
      "force" => 360,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "慈悲手"
    },
    %{
      "action" => "$N使出一招「大慈大悲手」，伏身疾进，双掌自下扫向$n的$l",
      "force" => 550,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 0,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "大慈大悲手"
    },
    %{
      "action" => "$N使出一招「金刚手」，飞身横跃，双掌前后击出，抓向$n的咽喉",
      "force" => 500,
      "attack" => 120,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 0,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "金刚手"
    },
    %{
      "action" => "$N使出一招「六臂智慧手」，顿时劲气弥漫，天空中出现无数掌影打",
      "force" => 500,
      "attack" => 120,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 0,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "六臂智慧手"
    }
  ]

  @impl true
  def id(), do: "dacidabei-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 70}

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
      "yin" => Kantele.Combat.Skills.Performs.DacidabeiShou.Yin
    }
  end
end

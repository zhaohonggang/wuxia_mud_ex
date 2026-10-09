defmodule Kantele.Combat.Skills.WuzhanMei do
  @moduledoc """
  武学实装「wuzhan-mei」（源 wuzhan-mei.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuzhan_mei/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招“五展梅”「冬梅初吐蕊」，手中$w犹如点点淡黄色的梅蕊刺向$n的$l",
      "force" => 60,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 2,
      "damage" => 70,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "冬梅初吐蕊"
    },
    %{
      "action" => "$N使出“五展梅”「幼梅傲霜雪」，$n只觉剑气扑面而来，仿佛置身冰天雪地中，\\n",
      "force" => 100,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 0,
      "damage" => 90,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "幼梅傲霜雪"
    },
    %{
      "action" => "$N一招“五展梅”「劲梅笑迎春」，$w连续划出几个圆圈，剑势如朵朵梅花，\\n",
      "force" => 150,
      "attack" => 0,
      "parry" => 30,
      "dodge" => -2,
      "damage" => 110,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "劲梅笑迎春"
    },
    %{
      "action" => "$N一腾身，$w飞舞，正是“五展梅”「腊梅暗香浮」,$n竟似闻到淡淡梅花幽香，\\n",
      "force" => 200,
      "attack" => 0,
      "parry" => 50,
      "dodge" => -4,
      "damage" => 130,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "腊梅暗香浮"
    },
    %{
      "action" => "$N向前跨上一步，手中$w使出“五展梅”「红梅展新枝」,剑光爆涨，\\n",
      "force" => 400,
      "attack" => 0,
      "parry" => 70,
      "dodge" => -6,
      "damage" => 150,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "红梅展新枝"
    },
    %{
      "action" => "$N手中的$w一晃，使出“五展梅”终极招式「五梅花枝俏」,五式合作一式，\\n",
      "force" => 600,
      "attack" => 0,
      "parry" => 90,
      "dodge" => -8,
      "damage" => 170,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "五梅花枝俏"
    }
  ]

  @impl true
  def id(), do: "wuzhan-mei"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 20, neili: 0}

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

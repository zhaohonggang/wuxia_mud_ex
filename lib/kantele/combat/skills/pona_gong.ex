defmodule Kantele.Combat.Skills.PonaGong do
  @moduledoc """
  武学实装「pona-gong」（源 pona-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pona_gong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「起手式」，身体右甩，屈肘反切，双拳蓄势而发，击向$n的$l",
      "force" => 180,
      "attack" => 0,
      "parry" => -2,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "起手式"
    },
    %{
      "action" => "$N一式「石破天惊」，左掌向上，右掌向下，拳风吡啪爆响，一股劲力直冲$n的$l",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 9,
      "damage_type" => "瘀伤",
      "skill_name" => "石破惊天"
    },
    %{
      "action" => "$N全身提气，腾空飞起，一式「铁闩横门」，双拳双腿齐出，来势汹汹，令$n无可躲藏",
      "force" => 230,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 29,
      "damage_type" => "瘀伤",
      "skill_name" => "铁闩横门"
    },
    %{
      "action" => "$N神情凝重，双掌虚含，掌缘下沉，大喝一声，一式「千斤坠地」，缓缓向$n推出",
      "force" => 270,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 39,
      "damage_type" => "瘀伤",
      "skill_name" => "千斤坠地"
    },
    %{
      "action" => "$N一臂前伸，一臂后指，一式「傍花拂柳」，身行急闪直$n身前，攻向$n的$l",
      "force" => 320,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 49,
      "damage_type" => "瘀伤",
      "skill_name" => "傍花拂柳"
    },
    %{
      "action" => "$N一式「金刚挚尾」，右拳由下至上，左拳从左到右，迅雷不及掩耳之势双双击向$n的$l",
      "force" => 380,
      "attack" => 0,
      "parry" => -5,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 59,
      "damage_type" => "瘀伤",
      "skill_name" => "金刚挚尾"
    },
    %{
      "action" => "$N两目内视，双手内笼，一式「封闭手」，双拳打向$n，只见$n躲闪过去，又击向$n的$l",
      "force" => 420,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 69,
      "damage_type" => "瘀伤",
      "skill_name" => "封闭手"
    },
    %{
      "action" => "$N调整内息，紧握双拳，一式「粉石碎玉」，全身发出暴豆般的响声，用尽全身力量击向$n的$l",
      "force" => 480,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "粉石碎玉"
    }
  ]

  @impl true
  def id(), do: "pona-gong"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 10}

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

defmodule Kantele.Combat.Skills.XuanfengTui do
  @moduledoc """
  武学实装「xuanfeng-tui」（源 xuanfeng-tui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuanfeng_tui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手虚晃，左脚猛地飞起，一式「风起云涌」，脚尖踢向$n的$l",
      "force" => 80,
      "attack" => 10,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "风起云涌"
    },
    %{
      "action" => "$N别转身来抽身欲走，刹那间回身，右脚一式「空谷足音」猛踹$n",
      "force" => 100,
      "attack" => 20,
      "parry" => 50,
      "dodge" => 50,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "空谷足音"
    },
    %{
      "action" => "$N右脚同时踹出，既猛且准，一式「碧渊腾蛟」，踢中的$n的胸口",
      "force" => 160,
      "attack" => 30,
      "parry" => 55,
      "dodge" => 55,
      "damage" => 18,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "碧渊腾蛟"
    },
    %{
      "action" => "$N突然跃起，双足连环圈转，一式「秋风落叶」，足带风尘，攻向$n",
      "force" => 190,
      "attack" => 35,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 20,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "秋风落叶"
    },
    %{
      "action" => "$N两手护胸，双脚交叉踢起，一式「风扫残云」，脚脚不离$n周围",
      "force" => 220,
      "attack" => 35,
      "parry" => 70,
      "dodge" => 70,
      "damage" => 25,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "风扫残云"
    },
    %{
      "action" => "$N突然侧身，右脚自上而下一式「流星坠地」，照$n的面门直劈下来",
      "force" => 260,
      "attack" => 40,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 30,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "流星坠地"
    },
    %{
      "action" => "$N使一式「朔风吹雪」，全身突然飞速旋转，双足迅猛无及的踹向$n",
      "force" => 290,
      "attack" => 40,
      "parry" => 100,
      "dodge" => 100,
      "damage" => 30,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "朔风吹雪"
    },
    %{
      "action" => "$N抽身跃起，开声吐气，陡然一式「雷动九天」，双脚如旋风般踢向$n",
      "force" => 340,
      "attack" => 45,
      "parry" => 115,
      "dodge" => 115,
      "damage" => 35,
      "lvl" => 200,
      "damage_type" => "瘀伤",
      "skill_name" => "雷动九天"
    }
  ]

  @impl true
  def id(), do: "xuanfeng-tui"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 51}

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

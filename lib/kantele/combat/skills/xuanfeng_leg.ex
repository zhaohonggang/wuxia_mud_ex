defmodule Kantele.Combat.Skills.XuanfengLeg do
  @moduledoc """
  武学实装「xuanfeng-leg」（源 xuanfeng-leg.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuanfeng_leg/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手虚晃，左脚猛地飞起，一式「风起云涌」，脚尖晃动，踢",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "风起云涌"
    },
    %{
      "action" => "$N左脚顿地，别转身来抽身欲走，只一刹那间一回身，右脚一式",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 15,
      "damage_type" => "瘀伤",
      "skill_name" => "空谷足音"
    },
    %{
      "action" => "$N左手一挣，反手扭搭住$n的右手，右脚同时踹出，既猛且准，一",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "碧渊腾蛟"
    },
    %{
      "action" => "$N突然跃起，双足连环圈转，一式「秋风落叶」，足带风尘，攻向",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "秋风落叶"
    },
    %{
      "action" => "$N两手护胸，双脚交叉踢起，一式「风扫残云」，脚脚不离$n的面门左右",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "风扫残云"
    },
    %{
      "action" => "$N突然侧身，却步后退，一个前空翻，右脚自上而下一式「流星坠",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 45,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "流星坠地"
    },
    %{
      "action" => "$N使一式「朔风吹雪」，全身突然飞速旋转，双足忽前忽后，迅猛",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 110,
      "damage_type" => "瘀伤",
      "skill_name" => "朔风吹雪"
    },
    %{
      "action" => "$N抽身跃起，开声吐气，大喝一声：嗨！一式「雷动九天」，双脚",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 60,
      "lvl" => 130,
      "damage_type" => "瘀伤",
      "skill_name" => "雷动九天"
    }
  ]

  @impl true
  def id(), do: "xuanfeng-leg"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

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


  @impl true
  def perform_list() do
    %{
      "kuangfeng" => Kantele.Combat.Skills.Performs.XuanfengLeg.Kuangfeng
    }
  end
end

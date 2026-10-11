defmodule Kantele.Combat.Skills.LianhuanMizongtui do
  @moduledoc """
  武学实装「lianhuan-mizongtui」（源 lianhuan-mizongtui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lianhuan_mizongtui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手虚晃，左脚猛地飞起，一式「荡寇金汤」，脚尖晃动，踢向$n的$l",
      "force" => 80,
      "attack" => 10,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "荡寇金汤"
    },
    %{
      "action" => "$N左脚顿地，别转身来抽身欲走，只一刹那间一回身，右脚一式「幻影腿」，猛踹$n的$l",
      "force" => 100,
      "attack" => 20,
      "parry" => 50,
      "dodge" => 50,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "幻影腿"
    },
    %{
      "action" => "$N左手一挣，右脚飞一般踹出，既猛且准，一式「聚精汇积」，踢中的$n的胸口",
      "force" => 160,
      "attack" => 30,
      "parry" => 55,
      "dodge" => 55,
      "damage" => 18,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "聚精汇积"
    },
    %{
      "action" => "$N突然跃起，双足连环圈转，一式「无影无踪」，足带风尘，攻向$n的全身",
      "force" => 190,
      "attack" => 35,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 20,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "无影无踪"
    },
    %{
      "action" => "$N两手护胸，双脚交叉踢起，一式「双龙开破」，脚脚不离$n的面门左右",
      "force" => 220,
      "attack" => 35,
      "parry" => 70,
      "dodge" => 70,
      "damage" => 25,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "双龙开破"
    },
    %{
      "action" => "$N突然侧身，却步后退，一个前空翻，右脚自上而下一式「流星飞坠」，照$n的面门直劈下来",
      "force" => 260,
      "attack" => 40,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 30,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "流星飞坠"
    },
    %{
      "action" => "$N使一式「无形定位」，全身突然飞速旋转，双足忽前忽后，迅猛无及踹向$n的胸口",
      "force" => 290,
      "attack" => 40,
      "parry" => 100,
      "dodge" => 100,
      "damage" => 30,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "无形定位"
    },
    %{
      "action" => "$N抽身跃起，开声吐气，大喝一声，一式「连环迷踪」，双脚如旋风般踢向$n的$l",
      "force" => 340,
      "attack" => 45,
      "parry" => 115,
      "dodge" => 115,
      "damage" => 35,
      "lvl" => 200,
      "damage_type" => "瘀伤",
      "skill_name" => "连环迷踪"
    }
  ]

  @impl true
  def id(), do: "lianhuan-mizongtui"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 60}

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
      "lian" => Kantele.Combat.Skills.Performs.LianhuanMizongtui.Lian
    }
  end
end

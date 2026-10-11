defmodule Kantele.Combat.Skills.YinsuoJinling do
  @moduledoc """
  武学实装「yinsuo-jinling」（源 yinsuo-jinling.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yinsuo_jinling/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N端坐不动，一招「对台梳妆」，手中$w抖得笔直，对准$n$l直刺而去",
      "force" => 80,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 35,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "对台梳妆"
    },
    %{
      "action" => "$N身形一转，一招「云龙白鹤」，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 130,
      "attack" => 38,
      "parry" => 27,
      "dodge" => 43,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "抽伤",
      "skill_name" => "云龙白鹤"
    },
    %{
      "action" => "$N力贯鞭梢，一招「明月千里」，手中$w舞出满天鞭影，铺天盖地袭向$n全身",
      "force" => 160,
      "attack" => 45,
      "parry" => 29,
      "dodge" => 63,
      "damage" => 61,
      "lvl" => 80,
      "damage_type" => "抽伤",
      "skill_name" => "明月千里"
    },
    %{
      "action" => "$N一声娇喝，一招「映月无声」，手中$w变换莫测，从意想不到的方位扫向$n",
      "force" => 180,
      "attack" => 50,
      "parry" => 33,
      "dodge" => 65,
      "damage" => 68,
      "lvl" => 120,
      "damage_type" => "抽伤",
      "skill_name" => "映月无声"
    },
    %{
      "action" => "$N飞身一跃而起，凌空一招「影玉徵辉」，$w宛如蛟龙通天，携着飕飕破空之声袭向$n",
      "force" => 210,
      "attack" => 53,
      "parry" => 36,
      "dodge" => 76,
      "damage" => 73,
      "lvl" => 160,
      "damage_type" => "抽伤",
      "skill_name" => "影玉徵辉"
    },
    %{
      "action" => "$N身形飘逸无定，一招「金光泻地」，手中$w幻出无数鞭影，笼罩$n全身",
      "force" => 230,
      "attack" => 65,
      "parry" => 35,
      "dodge" => 92,
      "damage" => 91,
      "lvl" => 180,
      "damage_type" => "抽伤",
      "skill_name" => "金光泻地"
    },
    %{
      "action" => "$N身形飘逸无定，一招「蜃楼银沙」，手中$w幻出无数鞭影，笼罩$n全身",
      "force" => 251,
      "attack" => 66,
      "parry" => 40,
      "dodge" => 117,
      "damage" => 120,
      "lvl" => 200,
      "damage_type" => "抽伤",
      "skill_name" => "蜃楼银沙"
    }
  ]

  @impl true
  def id(), do: "yinsuo-jinling"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 55}

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
      "dian" => Kantele.Combat.Skills.Performs.YinsuoJinling.Dian,
      "feng" => Kantele.Combat.Skills.Performs.YinsuoJinling.Feng,
      "kai" => Kantele.Combat.Skills.Performs.YinsuoJinling.Kai
    }
  end
end

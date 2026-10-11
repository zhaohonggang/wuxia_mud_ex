defmodule Kantele.Combat.Skills.XiuluoDao do
  @moduledoc """
  武学实装「xiuluo-dao」（源 xiuluo-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiuluo_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N藏刀内收，一招「割肉饲鹰」，刀锋自下而上划了个半弧，向$n的",
      "force" => 120,
      "attack" => 30,
      "parry" => 10,
      "dodge" => 2,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "割肉饲鹰"
    },
    %{
      "action" => "$N左掌虚托右肘，一招「投身饿虎」，手中$w笔直划向$n的$l",
      "force" => 130,
      "attack" => 42,
      "parry" => 18,
      "dodge" => 10,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "投身饿虎"
    },
    %{
      "action" => "$N一招「斫头谢天」，$w绕颈而过，刷地一声自上而下向$n猛劈",
      "force" => 140,
      "attack" => 50,
      "parry" => 28,
      "dodge" => 15,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "斫头谢天"
    },
    %{
      "action" => "$N右手反执刀柄，一招「折骨出髓」，猛一挫身，$w直向$n的颈中斩去",
      "force" => 160,
      "attack" => 62,
      "parry" => 30,
      "dodge" => 25,
      "damage" => 45,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "折骨出髓"
    },
    %{
      "action" => "$N一招「挑身千灯」，无数刀尖化作点点繁星，向$n的$l挑去",
      "force" => 180,
      "attack" => 65,
      "parry" => 31,
      "dodge" => 18,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "挑身千灯"
    },
    %{
      "action" => "$N双手合执$w，一招「挖眼布施」，拧身急转，刀尖直刺向$n的双眼",
      "force" => 210,
      "attack" => 72,
      "parry" => 32,
      "dodge" => 22,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "挖眼布施"
    },
    %{
      "action" => "$N一招「剥皮书经」，手中$w划出一个大平十字，向$n纵横劈去",
      "force" => 240,
      "attack" => 74,
      "parry" => 35,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 130,
      "damage_type" => "割伤",
      "skill_name" => "剥皮书经"
    },
    %{
      "action" => "$N反转刀尖对准自己，一招「剜心决志」，全身一个翻滚，$w向$n拦腰斩去",
      "force" => 280,
      "attack" => 77,
      "parry" => 41,
      "dodge" => 27,
      "damage" => 72,
      "lvl" => 140,
      "damage_type" => "割伤",
      "skill_name" => "剜心决志"
    },
    %{
      "action" => "$N一招「烧身供佛」，$w的刀光仿佛化成一簇簇烈焰，将$n团团围绕",
      "force" => 320,
      "attack" => 79,
      "parry" => 42,
      "dodge" => 30,
      "damage" => 88,
      "lvl" => 150,
      "damage_type" => "割伤",
      "skill_name" => "烧身供佛"
    },
    %{
      "action" => "$N刀尖平指，一招「刺血满地」，一片片切骨刀气如飓风般裹向$n的全身",
      "force" => 330,
      "attack" => 87,
      "parry" => 45,
      "dodge" => 25,
      "damage" => 95,
      "lvl" => 160,
      "damage_type" => "割伤",
      "skill_name" => "刺血满地"
    }
  ]

  @impl true
  def id(), do: "xiuluo-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 69}

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
      "suoming" => Kantele.Combat.Skills.Performs.XiuluoDao.Suoming
    }
  end
end

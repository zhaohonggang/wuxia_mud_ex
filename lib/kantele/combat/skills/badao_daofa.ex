defmodule Kantele.Combat.Skills.BadaoDaofa do
  @moduledoc """
  武学实装「badao-daofa」（源 badao-daofa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/badao_daofa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N藏刀内收，刀锋自下而上划了个半弧，向$n的$l挥去",
      "force" => 193,
      "attack" => 33,
      "parry" => 5,
      "dodge" => 3,
      "damage" => 61,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N左掌虚托右肘，手中$w笔直划向$n的$l",
      "force" => 217,
      "attack" => 37,
      "parry" => 7,
      "dodge" => 9,
      "damage" => 68,
      "lvl" => 20,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w绕颈而过，刷地一声自上而下向$n猛劈",
      "force" => 225,
      "attack" => 38,
      "parry" => 7,
      "dodge" => 13,
      "damage" => 73,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N右手反执刀柄，猛一挫身，$w直向$n的颈中斩去",
      "force" => 239,
      "attack" => 41,
      "parry" => 9,
      "dodge" => 11,
      "damage" => 79,
      "lvl" => 60,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w幻出无数刀尖，化作点点繁星，向$n的$l挑去",
      "force" => 257,
      "attack" => 48,
      "parry" => 13,
      "dodge" => 11,
      "damage" => 83,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N双手合执$w，拧身急转，刀尖直刺向$n的双眼",
      "force" => 276,
      "attack" => 53,
      "parry" => 23,
      "dodge" => 19,
      "damage" => 89,
      "lvl" => 100,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w划出一个大平十字，向$n纵横劈去",
      "force" => 312,
      "attack" => 59,
      "parry" => 13,
      "dodge" => 17,
      "damage" => 97,
      "lvl" => 120,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N反转刀尖对准自己，全身一个翻滚，$w向$n拦腰斩去",
      "force" => 297,
      "attack" => 68,
      "parry" => 21,
      "dodge" => 18,
      "damage" => 113,
      "lvl" => 140,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w的刀光仿佛化成一簇簇烈焰，将$n团团围绕",
      "force" => 323,
      "attack" => 69,
      "parry" => 23,
      "dodge" => 29,
      "damage" => 117,
      "lvl" => 170,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N刀尖平指，一片片切骨刀气如飓风般裹向$n的全身",
      "force" => 317,
      "attack" => 78,
      "parry" => 25,
      "dodge" => 31,
      "damage" => 121,
      "lvl" => 200,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "badao-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

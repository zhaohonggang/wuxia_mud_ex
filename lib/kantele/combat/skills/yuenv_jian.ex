defmodule Kantele.Combat.Skills.YuenvJian do
  @moduledoc """
  武学实装「yuenv-jian」（源 yuenv-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yuenv_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w轻轻点向$n的$l，迅疾无比",
      "force" => 100,
      "attack" => 130,
      "parry" => 12,
      "dodge" => 120,
      "damage" => 70,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N长跃而起，手中的$w挽了一个剑花，猛然刺向$n",
      "force" => 120,
      "attack" => 140,
      "parry" => 15,
      "dodge" => 125,
      "damage" => 84,
      "lvl" => 20,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出回身侧步，手中的$w斜刺$n的$l",
      "force" => 140,
      "attack" => 140,
      "parry" => 10,
      "dodge" => 130,
      "damage" => 100,
      "lvl" => 50,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N却身提步，手中的$w似挡飞挡，似进非进，忽的直刺$n",
      "force" => 160,
      "attack" => 160,
      "parry" => 10,
      "dodge" => 138,
      "damage" => 110,
      "lvl" => 75,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w颤动的极快，只幌得$n眼花撩乱，浑不知从何攻来",
      "force" => 180,
      "attack" => 180,
      "parry" => 12,
      "dodge" => 145,
      "damage" => 125,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N剑柄提起，剑尖下指，有如提壶斟酒，直挥$n的$l",
      "force" => 200,
      "attack" => 185,
      "parry" => 18,
      "dodge" => 150,
      "damage" => 130,
      "lvl" => 130,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w由内自外一刺，没有任何花巧，然而来是快得不可思议",
      "force" => 220,
      "attack" => 210,
      "parry" => 15,
      "dodge" => 155,
      "damage" => 140,
      "lvl" => 160,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N轻叹一声，手中的$w化作一到长弧点向$n",
      "force" => 240,
      "attack" => 230,
      "parry" => 22,
      "dodge" => 170,
      "damage" => 150,
      "lvl" => 200,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一抖手中的$w，挽出数个剑花，笼罩了$n",
      "force" => 260,
      "attack" => 250,
      "parry" => 25,
      "dodge" => 185,
      "damage" => 155,
      "lvl" => 225,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一声轻笑，手中$w幻化作满天星点，不知刺向$n的何处",
      "force" => 320,
      "attack" => 280,
      "parry" => 30,
      "dodge" => 220,
      "damage" => 180,
      "lvl" => 250,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "yuenv-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 64, neili: 65}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "xin" => Kantele.Combat.Skills.Performs.YuenvJian.Xin
    }
  end
end

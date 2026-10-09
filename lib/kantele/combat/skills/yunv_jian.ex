defmodule Kantele.Combat.Skills.YunvJian do
  @moduledoc """
  武学实装「yunv-jian」（源 yunv-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yunv_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「落叶飘飞」，身形斜飞，手中$w轻轻点向$n的$l",
      "force" => 75,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 28,
      "damage" => 12,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N长跃而起，「流云经天」，$w猛然下刺",
      "force" => 70,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 10,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出「浪迹天涯」，挥剑直劈，威不可当",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N使「手揽星空」一招自上而下搏击，模拟冰轮横空、清光铺地的光景",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 24,
      "damage" => 27,
      "lvl" => 30,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w颤动，如鲜花招展来回挥削，只幌得$n眼花撩乱，浑不知从何攻来",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 32,
      "lvl" => 45,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N使出「浪迹天涯」剑柄提起，剑尖下指，有如提壶斟酒，直挥$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 32,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w由内自外一刺，左手如斟茶壶，使出「抚琴按萧」来",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 42,
      "damage" => 48,
      "lvl" => 75,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "yunv-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 20}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

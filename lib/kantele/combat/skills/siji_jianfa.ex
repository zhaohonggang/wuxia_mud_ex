defmodule Kantele.Combat.Skills.SijiJianfa do
  @moduledoc """
  武学实装「siji-jianfa」（源 siji-jianfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/siji_jianfa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一式「春暖花开」，手中$w由左至右横扫向向$n的$l",
      "force" => 60,
      "attack" => 5,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 33,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N踏上一步，「夏日炎炎」，手中$w盘旋飞舞出一道剑光刺向$n的$l",
      "force" => 120,
      "attack" => 15,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 51,
      "lvl" => 40,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w一抖，一招「秋风萧瑟」，斜斜一剑反腕撩出，攻向$n的$l",
      "force" => 150,
      "attack" => 64,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 85,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w连绕数个大圈，一式「冬掣寒星」，一道剑光飞向$n的$l",
      "force" => 180,
      "attack" => 95,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 125,
      "lvl" => 120,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "siji-jianfa"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 125, neili: 125}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

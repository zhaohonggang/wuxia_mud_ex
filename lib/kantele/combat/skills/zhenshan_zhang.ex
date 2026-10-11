defmodule Kantele.Combat.Skills.ZhenshanZhang do
  @moduledoc """
  武学实装「zhenshan-zhang」（源 zhenshan-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhenshan_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「力拔山河」，左掌虚晃一下，右手带起阵阵掌风拍向$n的$l",
      "force" => 100,
      "attack" => 18,
      "parry" => 15,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N纵身跃起，一式「开碑断石」，双掌自上而下拍向$n的$l",
      "force" => 200,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 40,
      "damage" => 45,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双掌呼地拍出，一招「风雨欲来」，带起阵阵飞沙走石，直击向$n的$l",
      "force" => 250,
      "attack" => 35,
      "parry" => 55,
      "dodge" => 50,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双掌齐出，幻做掌影重重，一招「地老天荒」拍向$n$l",
      "force" => 290,
      "attack" => 42,
      "parry" => 75,
      "dodge" => 70,
      "damage" => 43,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "zhenshan-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 54}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "da" => Kantele.Combat.Skills.Performs.ZhenshanZhang.Da
    }
  end
end

defmodule Kantele.Combat.Skills.XiaoQinna do
  @moduledoc """
  武学实装「xiao-qinna」（源 xiao-qinna.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiao_qinna/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N飞身一跃，双手如钩如戢，插向$n的$l",
      "force" => 60,
      "attack" => 0,
      "parry" => 1,
      "dodge" => 17,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N身形一跃，飞身扑上，右手直直抓向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 3,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，双手齐抓向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 32,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N悄无声息的游走至$n身前，猛的一爪奋力抓向$n的$l",
      "force" => 132,
      "attack" => 0,
      "parry" => 19,
      "dodge" => 38,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "xiao-qinna"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 50}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

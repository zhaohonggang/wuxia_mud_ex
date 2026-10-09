defmodule Kantele.Combat.Skills.EmeiJiuyang do
  @moduledoc """
  武学实装「emei-jiuyang」（源 emei-jiuyang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 2 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/emei_jiuyang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N将峨嵋九阳神功运劲于臂，一掌凌空劈斩而出，划出一道炽热的黄芒",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N跨步上前，身形微微一展，双掌对准$n$l一并攻出",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "emei-jiuyang"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

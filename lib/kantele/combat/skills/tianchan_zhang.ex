defmodule Kantele.Combat.Skills.TianchanZhang do
  @moduledoc """
  武学实装「tianchan-zhang」（源 tianchan-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianchan_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手不住地忽伸忽缩，手臂关节喀喇声响，右掌一立，左掌啪的一下朝$n$l击去",
      "force" => 100,
      "attack" => 18,
      "parry" => 15,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形挫动，风声虎虎，接着朝$n连发八掌，一掌快似一掌，一掌猛似一掌",
      "force" => 200,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 40,
      "damage" => 45,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N攸地变爪为掌，身子不动，右臂陡长，潜运内力，一掌朝$n$l劈去",
      "force" => 250,
      "attack" => 35,
      "parry" => 55,
      "dodge" => 50,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一声怪啸，形如飘风，左掌已如风行电挚般拍向$n，掌未到，风先至，迅猛已极",
      "force" => 290,
      "attack" => 42,
      "parry" => 75,
      "dodge" => 70,
      "damage" => 43,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "tianchan-zhang"

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
end

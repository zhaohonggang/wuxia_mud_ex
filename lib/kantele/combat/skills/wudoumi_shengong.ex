defmodule Kantele.Combat.Skills.WudoumiShengong do
  @moduledoc """
  武学实装「wudoumi-shengong」（源 wudoumi-shengong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, perform_action_file, practice_skill, skill_improved, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wudoumi_shengong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N提运五斗米神功，呼的扑向$n，待至跟前，陡然一拳击向$n面门",
      "force" => 323,
      "attack" => 89,
      "parry" => 34,
      "dodge" => 31,
      "damage" => 58,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N丝毫不动声色，右掌平伸，左掌运起五斗米神功的劲力，呼的一声拍向$n",
      "force" => 362,
      "attack" => 103,
      "parry" => 47,
      "dodge" => 43,
      "damage" => 63,
      "lvl" => 160,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身形微微一展，一双手掌便似渗出血一般，双掌齐施，猛拍$n前胸",
      "force" => 413,
      "attack" => 122,
      "parry" => 51,
      "dodge" => 48,
      "damage" => 75,
      "lvl" => 180,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一声呼啸，双掌回收，凌空划出一个圆圈，顿时一股热浪直涌$n而出",
      "force" => 451,
      "attack" => 113,
      "parry" => 47,
      "dodge" => 41,
      "damage" => 83,
      "lvl" => 200,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "wudoumi-shengong"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "gui" => Kantele.Combat.Skills.Performs.WudoumiShengong.Gui
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.WudoumiShengong.Powerup
    }
  end
end

defmodule Kantele.Combat.Skills.WudoumiShengong do
  @moduledoc """
  武学实装「wudoumi-shengong」（源 wudoumi-shengong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, perform_action_file, practice_skill, skill_improved, valid_force
  - perform/exert 路由骨架见 tmp/perf_out/wudoumi_shengong/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

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

  # LPC `valid_learn(object me)`（源 wudoumi-shengong.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      (personality != "心狠手辣") and (personality != "国士无双") ->
        {:error, "你暗想这五斗米神功损人不利己，修来何用？\n"}

      Stats.con(stats) < 24 ->
        {:error, "你按照法门运转了下内息，忽然只觉丹田一阵搅疼。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的基本内功火候不足，不能学五斗米神功。\n"}

      Stats.skill(stats, "unarmed") < 50 ->
        {:error, "你的基本拳脚火候不足，不能学五斗米神功。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力修为不足，不能学五斗米神功。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功水平不够，难以锻炼更深厚的五斗米神功。\n"}

      true ->
        :ok
    end
  end

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :personality)
  defp personality_of(_character), do: nil
end

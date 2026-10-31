defmodule Kantele.Combat.Skills.YoushenZhang do
  @moduledoc """
  武学实装「youshen-zhang」（源 youshen-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 3 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/youshen_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形游走不定，在$n身旁围绕数圈，陡然间“呼”的一掌向$n$l劈落",
      "force" => 260,
      "attack" => 40,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形一展，已然拔地而起，双掌缤纷拍出数掌，尽数攻向$n的$l",
      "force" => 290,
      "attack" => 40,
      "parry" => 100,
      "dodge" => 100,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N抽身跃起，退后数步，陡然间却又疾身而上，朝着$n的$l处猛拍一掌",
      "force" => 320,
      "attack" => 45,
      "parry" => 115,
      "dodge" => 115,
      "damage" => 35,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "youshen-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 60}

  # LPC `valid_learn(object me)`（源 youshen-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "学习游身八卦掌必须空手。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法学游身八卦掌。\n"}

      Stats.skill(stats, "dodge") < 80 ->
        {:error, "你的基本轻功火候不够，无法学游身八卦掌。\n"}

      Stats.skill(stats, "unarmed") < 80 ->
        {:error, "你的基本拳脚火候不够，无法学游身八卦掌。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力太弱，无法练游身八卦掌。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你的基本拳脚水平有限，无法领会更高深的游身八卦掌。\n"}

      Stats.skill(stats, "dodge") < lvl ->
        {:error, "你的基本轻功水平有限，无法领会更高深的游身八卦掌。\n"}

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
      "fan" => Kantele.Combat.Skills.Performs.YoushenZhang.Fan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

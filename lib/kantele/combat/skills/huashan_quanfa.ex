defmodule Kantele.Combat.Skills.HuashanQuanfa do
  @moduledoc """
  武学实装「huashan-quanfa」（源 huashan-quanfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/huashan_quanfa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「云里乾坤」，右拳至左拳之底穿出，对准$n$l猛然攻去",
      "force" => 50,
      "attack" => 15,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "云里乾坤"
    },
    %{
      "action" => "$N左拳突然张开，拳开变掌，一招「雾里看花」便往$n的$l招呼过去",
      "force" => 65,
      "attack" => 17,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 23,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "雾里看花"
    },
    %{
      "action" => "$N两手虎口相对，往内一圈，一招「金鼓齐鸣」往$n的$l击出",
      "force" => 85,
      "attack" => 21,
      "parry" => 33,
      "dodge" => 31,
      "damage" => 28,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "金鼓齐鸣"
    },
    %{
      "action" => "$N步履一沉，左拳虚晃一招，右拳使出「梅花弄影」击向$n$l",
      "force" => 110,
      "attack" => 35,
      "parry" => 45,
      "dodge" => 42,
      "damage" => 33,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "梅花弄影"
    }
  ]

  @impl true
  def id(), do: "huashan-quanfa"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 45}

  # LPC `valid_learn(object me)`（源 huashan-quanfa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练华山拳法必须空手。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，无法学华山拳法。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练华山拳法。\n"}

      Stats.skill(stats, "cuff") < 20 ->
        {:error, "你的基本拳法火候太浅。\n"}

      Stats.skill(stats, "cuff") < lvl ->
        {:error, "你的基本拳法水平有限，无法领会更高深的华山拳法。\n"}

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
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

defmodule Kantele.Combat.Skills.BadaoDaofa do
  @moduledoc """
  武学实装「badao-daofa」（源 badao-daofa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/badao_daofa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N藏刀内收，刀锋自下而上划了个半弧，向$n的$l挥去",
      "force" => 193,
      "attack" => 33,
      "parry" => 5,
      "dodge" => 3,
      "damage" => 61,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N左掌虚托右肘，手中$w笔直划向$n的$l",
      "force" => 217,
      "attack" => 37,
      "parry" => 7,
      "dodge" => 9,
      "damage" => 68,
      "lvl" => 20,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w绕颈而过，刷地一声自上而下向$n猛劈",
      "force" => 225,
      "attack" => 38,
      "parry" => 7,
      "dodge" => 13,
      "damage" => 73,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N右手反执刀柄，猛一挫身，$w直向$n的颈中斩去",
      "force" => 239,
      "attack" => 41,
      "parry" => 9,
      "dodge" => 11,
      "damage" => 79,
      "lvl" => 60,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w幻出无数刀尖，化作点点繁星，向$n的$l挑去",
      "force" => 257,
      "attack" => 48,
      "parry" => 13,
      "dodge" => 11,
      "damage" => 83,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N双手合执$w，拧身急转，刀尖直刺向$n的双眼",
      "force" => 276,
      "attack" => 53,
      "parry" => 23,
      "dodge" => 19,
      "damage" => 89,
      "lvl" => 100,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w划出一个大平十字，向$n纵横劈去",
      "force" => 312,
      "attack" => 59,
      "parry" => 13,
      "dodge" => 17,
      "damage" => 97,
      "lvl" => 120,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N反转刀尖对准自己，全身一个翻滚，$w向$n拦腰斩去",
      "force" => 297,
      "attack" => 68,
      "parry" => 21,
      "dodge" => 18,
      "damage" => 113,
      "lvl" => 140,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w的刀光仿佛化成一簇簇烈焰，将$n团团围绕",
      "force" => 323,
      "attack" => 69,
      "parry" => 23,
      "dodge" => 29,
      "damage" => 117,
      "lvl" => 170,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N刀尖平指，一片片切骨刀气如飓风般裹向$n的全身",
      "force" => 317,
      "attack" => 78,
      "parry" => 25,
      "dodge" => 31,
      "damage" => 121,
      "lvl" => 200,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "badao-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 60}

  # LPC `valid_learn(object me)`（源 badao-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      (personality != "心狠手辣") and (personality != "国士无双") ->
        {:error, "你觉得这霸刀刀法实在过于狠毒，自己委实学不会。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力不足，没有办法练霸刀刀法，多练些内力再来吧。\n"}

      Stats.skill(stats, "blade") < 180 ->
        {:error, "你的基本刀法火候太浅，没有办法练霸刀刀法。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅，没有办法练霸刀刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平还不够，无法领会更高深的霸刀刀法。\n"}

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :personality)
  defp personality_of(_character), do: nil
end

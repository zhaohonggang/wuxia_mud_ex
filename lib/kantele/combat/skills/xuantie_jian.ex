defmodule Kantele.Combat.Skills.XuantieJian do
  @moduledoc """
  武学实装「xuantie-jian」（源 xuantie-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xuantie_jian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N手中的$w荡出，就如大江东去，威力势不可挡",
      "force" => 250,
      "attack" => 170,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 230,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N踏上一步，手中$w舞出一道剑光劈向$n的$l",
      "force" => 310,
      "attack" => 280,
      "parry" => 79,
      "dodge" => 33,
      "damage" => 224,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w一抖，一剑刺出，攻向$n的$l，没有半点花巧",
      "force" => 330,
      "attack" => 290,
      "parry" => 85,
      "dodge" => 41,
      "damage" => 235,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w微微颤动，忽然刺出，一道剑光射向$n的$l",
      "force" => 360,
      "attack" => 295,
      "parry" => 92,
      "dodge" => 45,
      "damage" => 239,
      "lvl" => 120,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N横过$w，蓦然横扫$n，气势如虹，荡气回肠",
      "force" => 340,
      "attack" => 297,
      "parry" => 99,
      "dodge" => 47,
      "damage" => 248,
      "lvl" => 160,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中的$w连削带刺，夹带着一阵旋风掠过$n全身",
      "force" => 380,
      "attack" => 300,
      "parry" => 100,
      "dodge" => 50,
      "damage" => 300,
      "lvl" => 200,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "xuantie-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 70}

  # LPC `valid_learn(object me)`（源 xuantie-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      Stats.int(stats) < 34 ->
        {:error, "你的先天悟性太差，无法领会玄铁剑法。\n"}

      Stats.str(stats) < 34 ->
        {:error, "你的先天膂力孱弱，无法学习玄铁剑法。\n"}

      personality == "心狠手辣" ->
        {:error, "你一心想杀尽敌人，没能理解玄铁剑法的的真正含义。\n"}

      personality == "阴险奸诈" ->
        {:error, "你一心想怎么学好剑法去害人，结果没能理解玄铁剑法。\n"}

      Stats.skill(stats, "force") < 380 ->
        {:error, "你的内功火候不到，无法学习玄铁剑法。\n"}

      Stats.skill(stats, "martial-cognize") < 220 ->
        {:error, "你武学修养不足，无法领悟玄铁剑法！\n"}

      not is_nil(max_neili) and max_neili < 5000 ->
        {:error, "你的内力太差，无法学习玄铁剑法。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功水平有限，无法领会更高深的玄铁剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的玄铁剑法。\n"}

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
      "dong" => Kantele.Combat.Skills.Performs.XuantieJian.Dong,
      "juan" => Kantele.Combat.Skills.Performs.XuantieJian.Juan,
      "xunlei" => Kantele.Combat.Skills.Performs.XuantieJian.Xunlei
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

defmodule Kantele.Combat.Skills.WushengZhao do
  @moduledoc """
  武学实装「wusheng-zhao」（源 wusheng-zhao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/wusheng_zhao/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左爪前伸，带着丝丝蓝阴鬼气，一式「元神出窍」，猛得向$n的顶门插下",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双掌连拍，筑起一道气墙推向$n，忽然一爪「鬼魅穿心」冲破气墙直插$n的$l",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出「血鬼锁」双爪游向$n扣住$l，气劲激发往左右两下一拉，便要将$n割成碎片",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 40,
      "lvl" => 20,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N双爪拢住$n，使一式「炼狱鬼嚎」，阴毒内功随爪尖透入$n体内，直袭各大关节",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 60,
      "lvl" => 30,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N力透指尖，向$n虚虚实实连抓十五爪，「妖风袭体」带动无数阴气缠住$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 60,
      "lvl" => 40,
      "damage_type" => "拉伤"
    },
    %{
      "action" => "$N一式「索命妖手」，左爪上下翻动形成无数爪影，右臂一伸，鬼魅般抓向$n的$l",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 67,
      "lvl" => 50,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N探手上前，顺着$n的手臂攀缘直上，变手为爪，一招「孤魂驭魔」抓向$n的$l",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 70,
      "lvl" => 70,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "wusheng-zhao"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 31}

  # LPC `valid_learn(object me)`（源 wusheng-zhao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练五圣毒爪必须空手。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力太弱，无法练五圣毒爪。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本爪法水平有限，无法领会更高深的五圣毒爪。\n"}

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
      "lian" => Kantele.Combat.Skills.Performs.WushengZhao.Lian
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

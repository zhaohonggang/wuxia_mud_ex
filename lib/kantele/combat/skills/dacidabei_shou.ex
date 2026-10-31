defmodule Kantele.Combat.Skills.DacidabeiShou do
  @moduledoc """
  武学实装「dacidabei-shou」（源 dacidabei-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/dacidabei_shou/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「莲花手」，双掌合十，直直撞向$n的前胸",
      "force" => 120,
      "attack" => 70,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "莲花手"
    },
    %{
      "action" => "$N使出一招「观音手」，飞身跃起，双手如勾，抓向$n的$l",
      "force" => 170,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "观音手"
    },
    %{
      "action" => "$N使出一招「佛母手」，运力于指，直取$n的$l",
      "force" => 220,
      "attack" => 60,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "佛母手"
    },
    %{
      "action" => "$N使出一招「红阎婆罗手」，怒吼一声，一掌当头拍向$n的$l",
      "force" => 250,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "红阎婆罗手"
    },
    %{
      "action" => "$N使出一招「慈悲手」，猛冲向前，掌如游龙般攻向$n",
      "force" => 360,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "慈悲手"
    },
    %{
      "action" => "$N使出一招「大慈大悲手」，伏身疾进，双掌自下扫向$n的$l",
      "force" => 550,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 0,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "大慈大悲手"
    },
    %{
      "action" => "$N使出一招「金刚手」，飞身横跃，双掌前后击出，抓向$n的咽喉",
      "force" => 500,
      "attack" => 120,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 0,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "金刚手"
    },
    %{
      "action" => "$N使出一招「六臂智慧手」，顿时劲气弥漫，天空中出现无数掌影打",
      "force" => 500,
      "attack" => 120,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 0,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "六臂智慧手"
    }
  ]

  @impl true
  def id(), do: "dacidabei-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 70}

  # LPC `valid_learn(object me)`（源 dacidabei-shou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练大慈大悲手必须空手。\n"}

      not is_nil(max_neili) and max_neili < 3500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 250 ->
        {:error, "你的内功火候太浅。\n"}

      (Stats.dex(stats) < 26) or (Stats.con(stats) < 26) ->
        {:error, "你的先天不足，无法理解大慈大悲手。\n"}

      Stats.skill(stats, "buddhism") < 200 ->
        {:error, "你对禅宗心法的知识了解太少，无法理解大慈大悲手。\n"}

      (Stats.skill(stats, "buddhism") < lvl) and (Stats.skill(stats, "buddhism") < 300) ->
        {:error, "你受禅宗心法知识的知识所限，难以进一步领悟大慈大悲手。\n"}

      Stats.skill(stats, "hand") < lvl ->
        {:error, "你的基本手法水平有限，无法领会更高深的大慈大悲手。\n"}

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

  @impl true
  def perform_list() do
    %{
      "yin" => Kantele.Combat.Skills.Performs.DacidabeiShou.Yin
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

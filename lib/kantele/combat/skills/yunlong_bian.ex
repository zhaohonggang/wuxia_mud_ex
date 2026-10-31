defmodule Kantele.Combat.Skills.YunlongBian do
  @moduledoc """
  武学实装「yunlong-bian」（源 yunlong-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yunlong_bian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N单手一扬，一招「开天辟地」，手中$w抖得笔直，对准$n当头罩下",
      "force" => 80,
      "attack" => 1,
      "parry" => 3,
      "dodge" => 3,
      "damage" => 2,
      "lvl" => 0,
      "damage_type" => "劈伤",
      "skill_name" => "开天辟地"
    },
    %{
      "action" => "$N身形一转，一招「龙腾四海」，手中$w如矫龙般腾空一卷，猛地击向$n",
      "force" => 90,
      "attack" => 3,
      "parry" => 5,
      "dodge" => 7,
      "damage" => 6,
      "lvl" => 10,
      "damage_type" => "劈伤",
      "skill_name" => "龙腾四海"
    },
    %{
      "action" => "$N唰的一抖长鞭，一招「矫龙出水」，手中$w抖得笔直，刺向$n双眼",
      "force" => 110,
      "attack" => 9,
      "parry" => 8,
      "dodge" => 13,
      "damage" => 8,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "矫龙出水"
    },
    %{
      "action" => "$N力贯鞭梢，一招「破云见日」，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "force" => 118,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 4,
      "damage" => 9,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "破云见日"
    },
    %{
      "action" => "$N运气于腕，一招「开山裂石」，手中$w向一根铜棍般直击向$n",
      "force" => 128,
      "attack" => 11,
      "parry" => 10,
      "dodge" => 7,
      "damage" => 8,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "开山裂石"
    },
    %{
      "action" => "$N单臂一挥，一招「玉带围腰」，手中$w直击向$n腰肋",
      "force" => 136,
      "attack" => 13,
      "parry" => 5,
      "dodge" => 1,
      "damage" => 12,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "玉带围腰"
    },
    %{
      "action" => "$N高高跃起，一招「大漠孤烟」，手中$w笔直向$n当头罩下",
      "force" => 148,
      "attack" => 21,
      "parry" => 15,
      "dodge" => 13,
      "damage" => 18,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "大漠孤烟"
    }
  ]

  @impl true
  def id(), do: "yunlong-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 38}

  # LPC `valid_learn(object me)`（源 yunlong-bian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (not (Skill.wielding?(character))) or (Skill.wielded_skill_type(character) != "whip") ->
        {:error, "你必须先找一条鞭子才能练鞭法。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不足，没有办法练云龙鞭法。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "whip") < 10 ->
        {:error, "你的基本鞭法火候太浅。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的云龙鞭法。\n"}

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
      "chan" => Kantele.Combat.Skills.Performs.YunlongBian.Chan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

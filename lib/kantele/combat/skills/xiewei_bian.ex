defmodule Kantele.Combat.Skills.XieweiBian do
  @moduledoc """
  武学实装「xiewei-bian」（源 xiewei-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/xiewei_bian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N单手一扬，一招「天蝎爪」，手中$w抖得笔直，直点$n的双眼",
      "force" => 100,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 12,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N力贯鞭梢，一招「蝎尾钩」，手中$w舞出满天鞭影，横扫$n腰间",
      "force" => 130,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 17,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N运气于腕，一招「毒蝎蚀月」，手中$w向一根铜棍般直击$n胸部",
      "force" => 150,
      "attack" => 0,
      "parry" => 19,
      "dodge" => 21,
      "damage" => 13,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N单臂一挥，一招「蛇游蝎行」，手中$w直击向$n腰肋",
      "force" => 175,
      "attack" => 0,
      "parry" => 27,
      "dodge" => 32,
      "damage" => 18,
      "lvl" => 60,
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N高高跃起，一招「天蝎藏针」，手中$w笔直向$n当头刺下",
      "force" => 225,
      "attack" => 0,
      "parry" => 37,
      "dodge" => 42,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "xiewei-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 50}

  # LPC `valid_learn(object me)`（源 xiewei-bian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练习蝎尾鞭。\n"}

      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你的内力不足，没有办法练习蝎尾鞭。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "whip") < 20 ->
        {:error, "你的基本鞭法火候太浅。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的蝎尾鞭。\n"}

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
      "teng" => Kantele.Combat.Skills.Performs.XieweiBian.Teng
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

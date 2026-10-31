defmodule Kantele.Combat.Skills.ShenghuoLing do
  @moduledoc """
  武学实装「shenghuo-ling」（源 shenghuo-ling.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/shenghuo_ling/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N踏上一步，忽地在地上一坐，已抱住了$n小腿。十指扣向$n小腿上的中都和",
      "force" => 180,
      "attack" => 70,
      "parry" => 70,
      "dodge" => 30,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "突然之间，$N身形晃动，同时欺近，手中$w往$n身上划去。脚下不知如何移动，",
      "force" => 240,
      "attack" => 80,
      "parry" => 81,
      "dodge" => 39,
      "damage" => 38,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N欺身直进，左手持$w向$n天灵盖上拍落。便在这一瞬之间，$n滚身向左，已",
      "force" => 260,
      "attack" => 90,
      "parry" => 95,
      "dodge" => 49,
      "damage" => 82,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N忽地放手，手中那柄$w尾端向上弹起，直奔$n手腕。",
      "force" => 280,
      "attack" => 95,
      "parry" => 102,
      "dodge" => 55,
      "damage" => 93,
      "lvl" => 120,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N忽然低头，一个头锤向$n撞来，$n不动声色，向旁又是一让，突觉胸口一阵",
      "force" => 320,
      "attack" => 97,
      "parry" => 139,
      "dodge" => 67,
      "damage" => 112,
      "lvl" => 160,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N忽然低头，一个头锤向$n撞来，$n不动声色，向旁又是一让，突觉胸口一麻，",
      "force" => 360,
      "attack" => 100,
      "parry" => 150,
      "dodge" => 75,
      "damage" => 130,
      "lvl" => 180,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "shenghuo-ling"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 70}

  # LPC `valid_learn(object me)`（源 shenghuo-ling.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.int(stats) < 32 ->
        {:error, "你先天悟性不足，无法领会圣火令法。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不到，无法学习圣火令法。\n"}

      Stats.skill(stats, "sword") < 200 ->
        {:error, "你的基本剑法火候不到，无法学习圣火令法。\n"}

      not is_nil(max_neili) and max_neili < 2400 ->
        {:error, "你的内功修为不足，无法学习圣火令法。\n"}

      Stats.query_str(stats) < 35 ->
        {:error, "你现在膂力太差，无法学习圣火令法。\n"}

      Stats.query_int(stats) < 40 ->
        {:error, "你现在无法领悟圣火令法的要诣。\n"}

      Stats.query_dex(stats) < 35 ->
        {:error, "你现在身法太差，无法学习圣火令法。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的内功修为不足，无法领会更高深的圣火令法。\n"}

      lvl > 200 ->
        {:error, "你的圣火神功水平有限，无法领会更高深的圣火令法。\n"}

      lvl > Stats.skill(stats, "shenghuo-shengong") ->
        {:error, "你的圣火神功水平有限，无法领会更高深的圣火令法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的圣火令法。\n"}

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
      "can" => Kantele.Combat.Skills.Performs.ShenghuoLing.Can,
      "hua" => Kantele.Combat.Skills.Performs.ShenghuoLing.Hua,
      "lian" => Kantele.Combat.Skills.Performs.ShenghuoLing.Lian,
      "xi" => Kantele.Combat.Skills.Performs.ShenghuoLing.Xi
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

defmodule Kantele.Combat.Skills.JiaohuaBangfa do
  @moduledoc """
  武学实装「jiaohua-bangfa」（源 jiaohua-bangfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/jiaohua_bangfa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N斜里冲前一步，身法诡异，手中$w急速横扫$n的$l",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N忽然直身飞入半空，又忽的飞身扑下，$w攻向$n的$l",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 45,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N原地一个后滚翻，身体向$n平飞过去，手中$w指向$n的$l",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N突然一个急转身，$w横扫一圈后挟着猛烈的劲道打向$n而去",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 45,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N向前顺势一滚，接着翻身跳起，手里$w斜向上击向$n的$l",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "jiaohua-bangfa"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 38}

  # LPC `valid_learn(object me)`（源 jiaohua-bangfa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力修为太弱，无法练叫花棒法。\n"}

      Stats.query_dex(stats) < 24 ->
        {:error, "你的身法不够灵活，无法练叫花棒法。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的叫花棒法。\n"}

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
end

defmodule Kantele.Combat.Skills.TianleiDao do
  @moduledoc """
  武学实装「tianlei-dao」（源 tianlei-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/tianlei_dao/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N手持$w一刀劈下，迅即无比，势不可当",
      "force" => 160,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 44,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N刀锋自下而上划了个半弧，$w忽深忽吐，刺向$n的颈部",
      "force" => 180,
      "attack" => 0,
      "parry" => 40,
      "dodge" => 30,
      "damage" => 58,
      "lvl" => 25,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N忽然将$w舞得天花乱坠，闪电般压向$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 35,
      "damage" => 56,
      "lvl" => 50,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一横$w，刀锋像门板一样向$n推去，封住$n所有的退路",
      "force" => 230,
      "attack" => 0,
      "parry" => 55,
      "dodge" => 45,
      "damage" => 62,
      "lvl" => 70,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N转身跃起，手舞$w，身与刀进合做一道电光射向$n",
      "force" => 265,
      "attack" => 0,
      "parry" => 75,
      "dodge" => 50,
      "damage" => 70,
      "lvl" => 90,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N挥舞$w，乱砍乱杀，$w化作道道白光，上下翻飞罩向$n",
      "force" => 270,
      "attack" => 0,
      "parry" => 85,
      "dodge" => 55,
      "damage" => 75,
      "lvl" => 110,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N将$w使得毫无章法，不守半点规矩，偏生快得出奇，$w挟风声劈向$n的$l",
      "force" => 290,
      "attack" => 0,
      "parry" => 90,
      "dodge" => 52,
      "damage" => 80,
      "lvl" => 130,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N大喝一声，手中的$w就如长虹一般向$n直劈而下",
      "force" => 310,
      "attack" => 0,
      "parry" => 95,
      "dodge" => 61,
      "damage" => 85,
      "lvl" => 150,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "tianlei-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 68}

  # LPC `valid_learn(object me)`（源 tianlei-dao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 160 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 60 ->
        {:error, "你的基本刀法火候不够，无法学习天雷绝刀。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平有限，无法领会更高深的天雷绝刀。\n"}

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
      "shan" => Kantele.Combat.Skills.Performs.TianleiDao.Shan,
      "zha" => Kantele.Combat.Skills.Performs.TianleiDao.Zha
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

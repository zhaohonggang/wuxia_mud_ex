defmodule Kantele.Combat.Skills.SuomingZhang do
  @moduledoc """
  武学实装「suoming-zhang」（源 suoming-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/suoming_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N微一躬身，使出「修罗索命」，$w携带着刺耳风声，擦地扫向$n的脚踝",
      "force" => 100,
      "attack" => 10,
      "parry" => 9,
      "dodge" => -5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N右手托住杖端，一招「招魂悼魄」居中一击，令其凭惯性倒向$n的肩头",
      "force" => 110,
      "attack" => 15,
      "parry" => 15,
      "dodge" => -10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一声狂喝，施一招「判官翻簿」，举起$w地满地乱敲，铺天盖地袭向$n",
      "force" => 120,
      "attack" => 20,
      "parry" => 19,
      "dodge" => -5,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N飞身跃起，一招「吊客临门」，身下$w往横里直打而出，挥向$n的裆部",
      "force" => 280,
      "attack" => 50,
      "parry" => 55,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 130,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N高举$w施展「无常抖索」，身形如鬼魅般飘出，对准$n的天灵盖一杖打下",
      "force" => 330,
      "attack" => 61,
      "parry" => 62,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N双眼发红，一招「百鬼恸哭」，将手中$w舞成千百根相似，击向$n全身各处要害",
      "force" => 350,
      "attack" => 65,
      "parry" => 67,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "suoming-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 70, neili: 69}

  # LPC `valid_learn(object me)`（源 suoming-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的索命杖法。\n"}

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

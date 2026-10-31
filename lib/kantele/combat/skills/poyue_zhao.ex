defmodule Kantele.Combat.Skills.PoyueZhao do
  @moduledoc """
  武学实装「poyue-zhao」（源 poyue-zhao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/poyue_zhao/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N使一招「上步劈坤势」，双手如钩如戢，插向$n的$l",
      "force" => 100,
      "attack" => 28,
      "parry" => 0,
      "dodge" => 17,
      "damage" => 13,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "上步劈坤势"
    },
    %{
      "action" => "$N身形一跃，费神扑上，使出一招「阴阳劲」，右手直直抓向$n的$l",
      "force" => 130,
      "attack" => 35,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "抓伤",
      "skill_name" => "阴阳劲"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，一招「追云手」打向$n的$l",
      "force" => 160,
      "attack" => 39,
      "parry" => 10,
      "dodge" => 32,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "追云手"
    },
    %{
      "action" => "$N使出一招「崩山啸海势」，猛的冲至$n跟前，双爪暴风骤雨般抓向$n",
      "force" => 172,
      "attack" => 42,
      "parry" => 19,
      "dodge" => 38,
      "damage" => 29,
      "lvl" => 60,
      "damage_type" => "抓伤",
      "skill_name" => "崩山啸海势"
    },
    %{
      "action" => "$N双手平提胸前，左手护住面门，一招「奔雷归穹势」右手推向$n的$l",
      "force" => 187,
      "attack" => 45,
      "parry" => 21,
      "dodge" => 41,
      "damage" => 33,
      "lvl" => 80,
      "damage_type" => "抓伤",
      "skill_name" => "奔雷归穹势"
    },
    %{
      "action" => "$N使出「抱残守缺势」，低喝一声，双手化掌为爪，一前一后抓向$n的$l",
      "force" => 203,
      "attack" => 51,
      "parry" => 22,
      "dodge" => 49,
      "damage" => 36,
      "lvl" => 100,
      "damage_type" => "抓伤",
      "skill_name" => "抱残守缺势"
    },
    %{
      "action" => "$N右腿斜插$n二腿之间，一招「紫电穿云势」，上手取目，下手反勾$n的裆部",
      "force" => 245,
      "attack" => 56,
      "parry" => 27,
      "dodge" => 53,
      "damage" => 41,
      "lvl" => 140,
      "damage_type" => "抓伤",
      "skill_name" => "紫电穿云势"
    },
    %{
      "action" => "$N使出「破岳疾劲势」，双爪如狂风骤雨般对准$n的$l连续抓出",
      "force" => 270,
      "attack" => 61,
      "parry" => 38,
      "dodge" => 58,
      "damage" => 45,
      "lvl" => 180,
      "damage_type" => "抓伤",
      "skill_name" => "破岳疾劲势"
    }
  ]

  @impl true
  def id(), do: "poyue-zhao"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 69}

  # LPC `valid_learn(object me)`（源 poyue-zhao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练破岳神爪必须空手。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，无法学破岳神爪。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练破岳神爪。\n"}

      Stats.skill(stats, "claw") < 20 ->
        {:error, "你的基本爪法等级太低，无法学破岳神爪。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本爪法火候水平有限，无法领会更高深的破岳神爪。\n"}

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
      "duan" => Kantele.Combat.Skills.Performs.PoyueZhao.Duan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

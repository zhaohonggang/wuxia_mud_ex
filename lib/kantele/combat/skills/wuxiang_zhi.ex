defmodule Kantele.Combat.Skills.WuxiangZhi do
  @moduledoc """
  武学实装「wuxiang-zhi」（源 wuxiang-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/wuxiang_zhi/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N随手前踏上一步，右指中宫直进，一式「无声无息」击向$n的$l",
      "force" => 80,
      "attack" => 20,
      "parry" => 20,
      "dodge" => -5,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "无声无息"
    },
    %{
      "action" => "$N一招「无欲无望」，轻唱一声佛号，左右看似随意一弹，一屡劲风已射向$n",
      "force" => 90,
      "attack" => 30,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "无欲无望"
    },
    %{
      "action" => "$N身形飘忽不定，一式「无法无天」，右指击向$n的$l",
      "force" => 150,
      "attack" => 50,
      "parry" => 35,
      "dodge" => 25,
      "damage" => 80,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "无法无天"
    },
    %{
      "action" => "$N脚踏七星步，突然一招「佛光普照」，左指从意想不到的角度攻向$n的各大要穴",
      "force" => 180,
      "attack" => 70,
      "parry" => 35,
      "dodge" => -10,
      "damage" => 100,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "佛光普照"
    },
    %{
      "action" => "$N一招「佛恩济世」，背朝$n，转身一指，令$n防不胜防",
      "force" => 230,
      "attack" => 70,
      "parry" => 30,
      "dodge" => 15,
      "damage" => 130,
      "lvl" => 160,
      "damage_type" => "割伤",
      "skill_name" => "佛恩济世"
    },
    %{
      "action" => "$N盘膝端坐，一招「佛法无边」，右手拇指弹出一道劲风，击向$n",
      "force" => 160,
      "attack" => 60,
      "parry" => 30,
      "dodge" => 5,
      "damage" => 100,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "佛法无边"
    },
    %{
      "action" => "$N双目紧闭，一招「无色无相」，聚集全身内力于一指射出一道无色劲气直逼$n",
      "force" => 250,
      "attack" => 100,
      "parry" => 50,
      "dodge" => 25,
      "damage" => 180,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "无色无相"
    }
  ]

  @impl true
  def id(), do: "wuxiang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 30}

  # LPC `valid_learn(object me)`（源 wuxiang-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练无相指必须空手。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学无相指。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练无相指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的无相指。\n"}

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
      "wuse" => Kantele.Combat.Skills.Performs.WuxiangZhi.Wuse
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

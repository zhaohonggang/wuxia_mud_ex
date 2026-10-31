defmodule Kantele.Combat.Skills.QiantianZhi do
  @moduledoc """
  武学实装「qiantian-zhi」（源 qiantian-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/qiantian_zhi/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施展出一招「雷风指」，右手拇指直刺$n$l处的要穴所在",
      "force" => 30,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "雷风指"
    },
    %{
      "action" => "$N使一招「山泽指」，左手轻轻一挥，右手刺向$n的檀中大穴",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 18,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "山泽指"
    },
    %{
      "action" => "$N双掌翻飞，一招「乾坤指」，暗藏玄机，中指戳向$n的$l",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 16,
      "damage" => 12,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "乾坤指"
    },
    %{
      "action" => "$N一声大喝，一式「太阴指」，双指齐出，攻向$n的胸口和$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 14,
      "damage" => 15,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "太阴指"
    },
    %{
      "action" => "$N连上数步，一招「少阳指」，左掌劈向$n，右手却暗袭$n的$l",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 22,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "少阳指"
    },
    %{
      "action" => "$N双手不住晃动，缓缓逼近$n，一招「少阴指」，笼罩了$n的$l",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 20,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "少阴指"
    },
    %{
      "action" => "$N一招「太阳指」，手指不住晃动，不离$n的$l方寸之间",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 20,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "太阳指"
    }
  ]

  @impl true
  def id(), do: "qiantian-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 11}

  # LPC `valid_learn(object me)`（源 qiantian-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    neili = neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练乾天指法必须空手。\n"}

      not is_nil(neili) and neili < 250 ->
        {:error, "你的内力不够，无法学乾天指法。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候不够，无法学乾天指法。\n"}

      Stats.skill(stats, "finger") < 20 ->
        {:error, "你的基本指法太浅，无法学乾天指法。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的乾天指法。\n"}

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
      "zhi" => Kantele.Combat.Skills.Performs.QiantianZhi.Zhi
    }
  end

  # LPC `me->query("neili")`：当前内力（vitals）
  defp neili_of(%{meta: %{vitals: %{neili: n}}}) when is_integer(n), do: n
  defp neili_of(_character), do: nil
end

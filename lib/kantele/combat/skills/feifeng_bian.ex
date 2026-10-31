defmodule Kantele.Combat.Skills.FeifengBian do
  @moduledoc """
  武学实装「feifeng-bian」（源 feifeng-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/feifeng_bian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N向上跃起，一招「凤凰展翅」，手中$w自下而上，击向$n的脸颊",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 20,
      "lvl" => 15,
      "damage_type" => "刮伤",
      "skill_name" => "凤凰展翅"
    },
    %{
      "action" => "$N一招「彩凤栖梧」，手中$w腾空一卷，直绕向$n的$l而去",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "彩凤栖梧"
    },
    %{
      "action" => "$N一招「鸾凤和鸣」，手中$w腾空一卷，一声脆响，猛地向$n劈头打下",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -15,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "劈伤",
      "skill_name" => "鸾凤和鸣"
    },
    %{
      "action" => "$N踏上一步，手中$w毫不停留，一招「游龙戏凤」，扫向$n的$l",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -30,
      "damage" => 60,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "游龙戏凤"
    },
    %{
      "action" => "$N半空一招「龙飞凤舞」，手中$w如游龙洗空，长凤戏羽，分点$n左右",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -35,
      "damage" => 70,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "龙飞凤舞"
    },
    %{
      "action" => "$N向前急进，手中$w圈转如虹，一招「龙凤呈祥」，罩向$n前胸",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -40,
      "damage" => 85,
      "lvl" => 75,
      "damage_type" => "内伤",
      "skill_name" => "龙凤呈祥"
    }
  ]

  @impl true
  def id(), do: "feifeng-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 39}

  # LPC `valid_learn(object me)`（源 feifeng-bian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (not (Skill.wielding?(character))) or (Skill.wielded_skill_type(character) != "whip") ->
        {:error, "你必须先找一条长鞭才能练鞭法。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候太浅，无法练飞凤鞭法。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为太弱，无法练飞凤鞭法。\n"}

      Stats.skill(stats, "whip") < 20 ->
        {:error, "你的基本鞭法等级太低，无法学飞凤鞭法。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的飞凤鞭法。\n"}

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
      "xi" => Kantele.Combat.Skills.Performs.FeifengBian.Xi
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

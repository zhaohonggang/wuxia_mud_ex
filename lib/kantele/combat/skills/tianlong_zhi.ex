defmodule Kantele.Combat.Skills.TianlongZhi do
  @moduledoc """
  武学实装「tianlong-zhi」（源 tianlong-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianlong_zhi/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手中指斜指而出，一招「天山指」已袭向$n$l",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "点穴",
      "skill_name" => "天龙式"
    },
    %{
      "action" => "$N飞身而起，左手食指一伸，一式「六绝指」罩向$n要穴",
      "force" => 140,
      "attack" => 5,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "点穴",
      "skill_name" => "天龙式"
    },
    %{
      "action" => "$N化掌为指，右手无名指连连指出，一股气流袭向$n$l",
      "force" => 155,
      "attack" => 10,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "点穴",
      "skill_name" => "天龙式"
    },
    %{
      "action" => "$N纵身而起，双手成指一式「天龙式」猛地指向$n$l",
      "force" => 220,
      "attack" => 40,
      "parry" => 21,
      "dodge" => 15,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "点穴",
      "skill_name" => "天龙式"
    }
  ]

  @impl true
  def id(), do: "tianlong-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

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
  @doc """
  学习门槛（对照 `tianlong-zhi.c` valid_learn，LPC 以 `return 1` 收尾，全显式门）
  """
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "canhe-zhi") > 0 ->
        {:error, "你已将这种指法融入参合指，不必再分开练习了。\n"}
      Skill.wielding?(character) or Skill.secondary_wielding?(character) ->
        {:error, "大天龙指必须空手。\n"}
      Stats.effective(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法学大天龙指。\n"}
      Stats.skill(stats, "finger") < 40 ->
        {:error, "你的基本指法火候不够，无法学大天龙指。\n"}
      not is_integer(max_neili) or max_neili < 1000 ->
        {:error, "你的内力太弱，无法练大天龙指。\n"}
      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法太差，无法领会更高深的大天龙指。\n"}
      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

end

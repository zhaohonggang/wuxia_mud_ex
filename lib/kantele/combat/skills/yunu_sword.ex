defmodule Kantele.Combat.Skills.YunuSword do
  @moduledoc """
  武学实装「yunu-sword」（源 yunu-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_effect
  - perform/exert 路由骨架见 tmp/perf_out/yunu_sword/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「穿针引线」，脚踏中宫，手中$w直指$n$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "穿针引线"
    },
    %{
      "action" => "$N剑随身转，一招「天衣无缝」，撒出一片剑影，罩向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "天衣无缝"
    },
    %{
      "action" => "$N舞动$w，使出一招「夜绣鸳鸯」剑光忽左忽右，闪烁不定，直刺$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "夜绣鸳鸯"
    },
    %{
      "action" => "$N一声娇喝，祭出「织女穿梭」，手中$w化为一道弧光，射向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "织女穿梭"
    },
    %{
      "action" => "$N忽然蹂身直上，一招「小鸟依人」，手中$w自下往上刺向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "小鸟依人"
    }
  ]

  @impl true
  def id(), do: "yunu-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 1}

  # LPC `valid_learn(object me)`（源 yunu-sword.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    gender = gender_of(character)

    cond do
      gender != "女性" ->
        {:error, "玉女金针十三剑是只有女子才能练的武功。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太差，没有办法练玉女金针十三剑。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，没有办法练玉女金针十三剑。\n"}

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
      "wushuang" => Kantele.Combat.Skills.Performs.YunuSword.Wushuang
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"
end

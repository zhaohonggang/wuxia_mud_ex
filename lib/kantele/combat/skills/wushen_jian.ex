defmodule Kantele.Combat.Skills.WushenJian do
  @moduledoc """
  武学实装「wushen-jian」（源 wushen-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, hit_ob, perform_action_file, practice_skill, skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wushen_jian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N反转手中$w，剑光夺目，将「",
      "force" => 430,
      "attack" => 147,
      "parry" => 128,
      "dodge" => 96,
      "damage" => 190,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中剑花突现，顿时剑光暴长，已将「",
      "force" => 420,
      "attack" => 154,
      "parry" => 120,
      "dodge" => 118,
      "damage" => 210,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N将$w一挥，长啸一声腾空而起，一式「",
      "force" => 420,
      "attack" => 156,
      "parry" => 120,
      "dodge" => 100,
      "damage" => 223,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N轻啸一声，右手$w虚刺$n左眼，突然右腕翻转，将「",
      "force" => 430,
      "attack" => 160,
      "parry" => 140,
      "dodge" => 120,
      "damage" => 248,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w剑路忽快忽慢，若隐若现，一剑「",
      "force" => 480,
      "attack" => 180,
      "parry" => 160,
      "dodge" => 140,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "wushen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 0}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

    @doc """
  学习门槛（对照 `wushen-jian.c` valid_learn，LPC 以 `return 1` 收尾，全显式门）
  """
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一柄剑才能够练习。\n"}
      Stats.query_int(stats) < 30 ->
        {:error, "你的先天悟性不足，没有办法练衡山五神剑。\n"}
      Stats.query_dex(stats) < 28 ->
        {:error, "你的先天身法孱弱，没有办法练衡山五神剑。\n"}
      Stats.skill(stats, "martial-cognize") < 180 ->
        {:error, "你觉得衡山五神剑极其深奥，依照自己的武学修养难以理解。\n"}
      not is_integer(max_neili) or max_neili < 4000 ->
        {:error, "你的内力修为不够，没有办法练衡山五神剑。\n"}
      Stats.skill(stats, "sword") < 200 ->
        {:error, "你的基本剑法太差，没有办法练衡山五神剑。\n"}
      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的衡山五神剑。\n"}
      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

@impl true
  def perform_list() do
    %{
      "hui" => Kantele.Combat.Skills.Performs.WushenJian.Hui,
      "qian" => Kantele.Combat.Skills.Performs.WushenJian.Qian,
      "shen" => Kantele.Combat.Skills.Performs.WushenJian.Shen
    }
  end
end

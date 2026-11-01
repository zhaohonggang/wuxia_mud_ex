defmodule Kantele.Combat.Skills.NianhuaZhi do
  @moduledoc """
  拈花指（对照 `kungfu/skill/nianhua-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/nianhua_zhi/`。

  学习门槛 `valid_learn/2`（force>=60 / max_neili>=300 / finger>=self）与练招消耗
  `practice_cost`（qi 50 / neili 64）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N侧身抬臂，右指划了个半圈，一式「瓶花落砚」击向$n的$l",
      "force" => 100,
      "attack" => 10,
      "dodge" => -5,
      "parry" => 15,
      "lvl" => 0,
      "skill_name" => "瓶花落砚"
    },
    %{
      "action" => "$N左掌虚托，一式「寒梅吐蕊」，右指穿腋疾出，指向$n的胸前",
      "force" => 140,
      "attack" => 15,
      "dodge" => -5,
      "parry" => 18,
      "lvl" => 10,
      "skill_name" => "寒梅吐蕊"
    },
    %{
      "action" => "$N俯身斜倚，左手半推，右手一式「初杏问酒」，向$n的$l划过",
      "force" => 170,
      "attack" => 20,
      "dodge" => 5,
      "parry" => 25,
      "lvl" => 20,
      "skill_name" => "初杏问酒"
    },
    %{
      "action" => "$N双目微睁，一式「露草斜阳」，双手幻化出千百个指影，拂向$n的$l",
      "force" => 210,
      "attack" => 28,
      "dodge" => 5,
      "parry" => 30,
      "damage" => 10,
      "lvl" => 30,
      "skill_name" => "露草斜阳"
    },
    %{
      "action" => "$N一式「仰月承霖」，左掌护住丹田，右手斜指苍天，蓄势点向$n的$l",
      "force" => 250,
      "attack" => 30,
      "dodge" => 15,
      "parry" => 35,
      "damage" => 10,
      "lvl" => 50,
      "skill_name" => "仰月承霖"
    },
    %{
      "action" => "$N双掌平托胸前，十指叉开，一式「叶底留莲」，指向$n的周身大穴",
      "force" => 280,
      "attack" => 45,
      "dodge" => 20,
      "parry" => 40,
      "damage" => 15,
      "lvl" => 70,
      "skill_name" => "叶底留莲"
    },
    %{
      "action" => "$N双掌翻飞，一式「清风拂桂」，指端迸出无数道劲气，射向$n的全身",
      "force" => 310,
      "attack" => 50,
      "dodge" => 25,
      "parry" => 48,
      "damage" => 20,
      "lvl" => 90,
      "skill_name" => "清风拂桂"
    },
    %{
      "action" => "$N一式「菊圃秋霜」，并指如刃，一束束锐利无俦的刀气，凌虚向$n的$l砍去",
      "force" => 370,
      "attack" => 60,
      "dodge" => 30,
      "parry" => 55,
      "damage" => 30,
      "lvl" => 120,
      "skill_name" => "菊圃秋霜"
    },
    %{
      "action" => "$N一式「伽叶微笑」，双手食指交叉，指端射出一缕罡气，穿过$n的$l",
      "force" => 400,
      "attack" => 68,
      "dodge" => 35,
      "parry" => 60,
      "damage" => 40,
      "lvl" => 150,
      "skill_name" => "伽叶微笑"
    },
    %{
      "action" => "$N左掌竖立胸前，一式「佛祖拈花」，右手食指扣住拇指，轻轻对着$n一弹",
      "force" => 440,
      "attack" => 75,
      "dodge" => 50,
      "parry" => 66,
      "damage" => 10,
      "lvl" => 180,
      "skill_name" => "佛祖拈花"
    }
  ]

  @impl true
  def id(), do: "nianhua-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 64（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 64}

  # LPC `valid_learn(object me)`（源 nianhua-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练拈花指必须空手。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学拈花指。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练拈花指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的拈花指。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"fuxue" => Kantele.Combat.Skills.Performs.NianhuaZhi.Fuxue}
  end
  def actions(), do: @actions

end

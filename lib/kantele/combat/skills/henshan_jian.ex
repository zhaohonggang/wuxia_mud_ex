defmodule Kantele.Combat.Skills.HenshanJian do
  @moduledoc """
  衡山剑法（对照 `kungfu/skill/henshan-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/henshan_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=80 / sword>=10 / sword>=henshan-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 30，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N右手$w慢慢指出，突然间在空中一颤，嗡嗡作响，剑光暴长，向$n刺去",
      "force" => 110,
      "dodge" => 28,
      "damage" => 30,
      "lvl" => 0
    },
    %{
      "action" => "$N手中$w如鬼如魅，竟已绕到$n背后，$n急忙转身，耳边只听得嗡嗡两声",
      "force" => 120,
      "dodge" => 24,
      "damage" => 25,
      "lvl" => 20
    },
    %{
      "action" => "$N手中$w寒光陡闪，手中的$w，猛地反刺，直指$n胸口。这一下出招快\n极，抑且如梦如幻，正是「百变千幻衡山云雾十三式」中的绝招",
      "force" => 120,
      "dodge" => 24,
      "damage" => 28,
      "lvl" => 35,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N不慌不忙犹如蓄势待发，手中$w刷的一剑「剑发琴音」，向$n$l刺去",
      "force" => 130,
      "dodge" => 30,
      "damage" => 35,
      "lvl" => 50,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N飞身跃起，一式「岁岁青苍」，$w发出一声长啸从半空中洒向$n的$l",
      "force" => 160,
      "dodge" => 38,
      "damage" => 45,
      "lvl" => 75,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "henshan-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=80 / sword>=10 / sword>=henshan-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 30（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 30}

  # LPC `valid_learn(object me)`（源 henshan-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 80 ->
        {:error, "你目前的内力修为不够，没有办法练衡山剑法。\n"}

      Stats.skill(stats, "sword") < 10 ->
        {:error, "你的基本剑法火候太浅，没有办法练衡山剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的衡山剑法。\n"}

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
    %{"huan" => Kantele.Combat.Skills.Performs.HenshanJian.Huan}
  end
  def actions(), do: @actions

end

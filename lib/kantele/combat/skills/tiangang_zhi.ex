defmodule Kantele.Combat.Skills.TiangangZhi do
  @moduledoc """
  天罡指（对照 `kungfu/skill/tiangang-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/tiangang_zhi/`。

  学习门槛 `valid_learn/2`（force>=100 / max_neili>=500 / finger>=self）与练招消耗
  `practice_cost`（qi 55 / neili 51）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill
  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N左手轻轻拨动，右手五指徐徐弹出拨，一式「浪起湖心」，拂向$n的$l",
      "force" => 90,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手上下起落，俯身掠向$n，一式「瀑落清潭」，左手化掌成指，汹涌袭向$n的$l",
      "force" => 140,
      "attack" => 5,
      "dodge" => 5,
      "parry" => 5,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手由拳变掌，右手扭曲如灵蛇，一式「龟蛇竞渡」，左右并用，拍向$n的$l",
      "force" => 170,
      "attack" => 10,
      "dodge" => 15,
      "parry" => 10,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一式「倒索攀山」，左手抽回，右手前探，戟指点向$n的$l",
      "force" => 190,
      "attack" => 20,
      "dodge" => 25,
      "parry" => 15,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一式「闪现雷鸣」，身影变幻不定地掠至$n身后，猛地拍向$n的$l",
      "force" => 220,
      "attack" => 30,
      "dodge" => 30,
      "parry" => 20,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N两臂大开大阖，吸一口气，一式「地动山摇」，劲力透彻，双手快速一拨，激出数道劲气逼向$n的$l",
      "force" => 270,
      "attack" => 40,
      "dodge" => 45,
      "parry" => 25,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形纵起，衣袂飘荡，双手轻轻拍动，一式「水拍云崖」，居高临下，连绵不绝拍向$n的$l",
      "force" => 300,
      "attack" => 50,
      "dodge" => 50,
      "parry" => 20,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N腾空而起，双掌合一，十指如钩，一招「泰山压顶」，疾向$n的击落，势道凶猛已极",
      "force" => 320,
      "attack" => 60,
      "dodge" => 55,
      "parry" => 25,
      "damage" => 70,
      "lvl" => 160,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "tiangang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法学天罡指穴法。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力太弱，无法练天罡指穴法。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法太差，无法领会更高深的天罡指穴法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 51（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"ling" => Kantele.Combat.Skills.Performs.TiangangZhi.Ling}
  end
  def actions(), do: @actions

end

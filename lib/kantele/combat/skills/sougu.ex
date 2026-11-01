defmodule Kantele.Combat.Skills.Sougu do
  @moduledoc """
  搜骨鹰爪功（对照 `kungfu/skill/sougu.c`）

  爪/抓法载体：`valid_enable("claw")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sougu/`。

  学习门槛 `valid_learn/2`（force>=100 / max_neili>=600 / str>=33）与练招消耗
  `practice_cost`（qi 55 / neili 57）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "\n$N双臂一拢，左爪直攻$n下盘，右爪却挟风雷之势推向$n腰间，一虚一实，正是一招「推爪式」",
      "force" => 120,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "\n$N身形陡起，如雄鹰击日般“倏”地从$n头顶越过，使一招「盖爪式」双爪疾向$n脑后击下",
      "force" => 190,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "\n$N就地一滚，突然到了$n身前，使一招「掏爪式」，右爪直奔$n小腹",
      "force" => 225,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "\n$N左爪护胸，右爪凝劲后发，一招「托爪式」，缓缓托向$n的$l",
      "force" => 265,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 100,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "\n$N身形诡异，疾速前扑，使一招「撩爪式」，直撩$n裆部",
      "force" => 310,
      "dodge" => 25,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "\n$N身形飘忽，陡然转到$n身后，一招「锁爪式」，双爪直向$n咽喉插下",
      "force" => 320,
      "dodge" => 35,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "\n$N一声厉啸，身形拔起，使出「千爪式」，由半空盘旋下击，$n顿觉漫天爪影，罩向全身死穴",
      "force" => 335,
      "dodge" => 40,
      "damage" => 55,
      "lvl" => 160,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "sougu"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 57（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 57}

  # LPC `valid_learn(object me)`（源 sougu.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练搜骨鹰爪功必须空手。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法学搜骨鹰爪功。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力太弱，无法学搜骨鹰爪功。\n"}

      Stats.query_str(stats) < 33 ->
        {:error, "你现在的膂力太差，还无法学搜骨鹰爪功。\n"}

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
    %{"muyeyingyang" => Kantele.Combat.Skills.Performs.Sougu.Muyeyingyang}
  end
  def actions(), do: @actions

end

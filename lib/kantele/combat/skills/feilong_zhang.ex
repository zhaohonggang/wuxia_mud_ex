defmodule Kantele.Combat.Skills.FeilongZhang do
  @moduledoc """
  飞龙杖法（对照 `kungfu/skill/feilong-zhang.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/feilong_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求持杖、max_neili>=500，本版以 force>=80 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N斜举$w, 一招「秦王鞭石」，斜肩铲背砸向$n的$l",
      "force" => 80,
      "attack" => 24,
      "dodge" => -5,
      "parry" => 20,
      "damage" => 35,
      "lvl" => 0
    },
    %{
      "action" => "$N一声大喝，使出一招「鲁达拔柳」, 手中$w自下而上扫向$n的$l",
      "force" => 100,
      "attack" => 30,
      "dodge" => -10,
      "parry" => 25,
      "damage" => 40,
      "lvl" => 30
    },
    %{
      "action" => "$N使出一招「霸王扛鼎」，将$w从肩头甩出砸向往$n的$l",
      "force" => 120,
      "attack" => 35,
      "dodge" => -5,
      "parry" => 24,
      "damage" => 50,
      "lvl" => 70
    },
    %{
      "action" => "$N身子一晃，一招「八仙醉打」，手中$w如狂风暴雨般向$n打出",
      "force" => 160,
      "attack" => 50,
      "dodge" => -5,
      "parry" => 45,
      "damage" => 60,
      "lvl" => 100
    },
    %{
      "action" => "$N一声咆哮，一招「长虹经天」, $w从手中掷出，飞向$n的$l",
      "force" => 180,
      "attack" => 61,
      "dodge" => -5,
      "parry" => 50,
      "damage" => 75,
      "lvl" => 120
    },
    %{
      "action" => "$N一招「飞龙一现」, 将手中$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 220,
      "attack" => 70,
      "dodge" => -5,
      "parry" => 60,
      "damage" => 90,
      "lvl" => 150
    }
  ]

  @impl true
  def id(), do: "feilong-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 feilong-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "staff" ->
        {:error, "你使用的武器不对。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力修为不足，难以修炼飞龙杖法。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功修为不够，难以修炼飞龙杖法。\n"}

      Stats.skill(stats, "staff") < 40 ->
        {:error, "你的基本杖法火候太浅，难以修炼飞龙杖法。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的飞龙杖法。\n"}

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
    %{"fei" => Kantele.Combat.Skills.Performs.FeilongZhang.Fei}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

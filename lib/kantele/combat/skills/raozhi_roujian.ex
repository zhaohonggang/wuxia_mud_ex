defmodule Kantele.Combat.Skills.RaozhiRoujian do
  @moduledoc """
  柔指柔剑（对照 `kungfu/skill/raozhi-roujian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/raozhi_roujian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=20 / sword>=self）与练招消耗
  `practice_cost`（qi 35 / neili 30）已按 LPC 迁移（2026-10-30）。须持剑检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N使出一招「天外流星」，手中$w如一条银蛇般刺向$n的$l",
      "force" => 120,
      "dodge" => 20,
      "parry" => 14,
      "damage" => 25,
      "lvl" => 0
    },
    %{
      "action" => "$N一式「落花满天」，手中$w化做满天剑影直刺向$n的$l",
      "force" => 120,
      "dodge" => 20,
      "parry" => 15,
      "damage" => 20,
      "lvl" => 10
    },
    %{
      "action" => "$N使出一招「窗含柔月」，手中$w挥舞，舞出数个剑花圈向$n的$l",
      "force" => 140,
      "dodge" => 15,
      "parry" => 16,
      "damage" => 25,
      "lvl" => 20
    },
    %{
      "action" => "$N轻轻一跃，一招「乘风归去」，却在转身之际对准$n$l斜斜挥出一剑",
      "force" => 150,
      "dodge" => 15,
      "parry" => 18,
      "damage" => 35,
      "lvl" => 30
    },
    %{
      "action" => "$N神态悠闲，手中$w凭空一指，一招「白云千载」轻妙地划向$n的$l",
      "force" => 130,
      "dodge" => 25,
      "parry" => 21,
      "damage" => 25,
      "lvl" => 40
    },
    %{
      "action" => "$N使出一招「星河影动」，剑光闪烁不定，若有若无地刺向$n$l",
      "force" => 120,
      "dodge" => 25,
      "parry" => 22,
      "damage" => 25,
      "lvl" => 50
    },
    %{
      "action" => "$N手中$w向外一分，一招「柳暗花明」反手对准$n$l一剑刺去",
      "force" => 110,
      "dodge" => 15,
      "parry" => 35,
      "damage" => 38,
      "lvl" => 60
    },
    %{
      "action" => "$N身形转个不停，突然一招「一点灵犀」使出，手中$w划出一道银弧，径刺$n$l",
      "force" => 150,
      "dodge" => 35,
      "parry" => 45,
      "damage" => 43,
      "lvl" => 70
    }
  ]

  @impl true
  def id(), do: "raozhi-roujian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的绕指柔剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35 / neili 30（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 30}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"chuan" => Kantele.Combat.Skills.Performs.RaozhiRoujian.Chuan}
  end
  def actions(), do: @actions

end

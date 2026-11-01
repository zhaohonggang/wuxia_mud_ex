defmodule Kantele.Combat.Skills.GuyueChan do
  @moduledoc """
  孤月铲法（对照 `kungfu/skill/guyue-chan.c`）

  铲/杖载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/guyue_chan/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求持杖、max_neili>=400，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N纵步上前，手中$w自下而上，沉猛无比地向$n的小腹挑去",
      "force" => 35,
      "attack" => 8,
      "dodge" => -10,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0
    },
    %{
      "action" => "$N快步跨出，左手平托$w，右掌猛推杖端，顶向$n的胸口",
      "force" => 50,
      "attack" => 10,
      "dodge" => -10,
      "parry" => 8,
      "damage" => 8,
      "lvl" => 30
    },
    %{
      "action" => "$N高举$w，全身跃起，手中$w朝着$n头盖天灵盖猛然击落下去",
      "force" => 65,
      "attack" => 15,
      "dodge" => -5,
      "parry" => 10,
      "damage" => 12,
      "lvl" => 60
    },
    %{
      "action" => "$N双手持杖如橹，对准$n猛地一搅，如同平地刮起一阵旋风",
      "force" => 80,
      "attack" => 18,
      "dodge" => -5,
      "parry" => 12,
      "damage" => 15,
      "lvl" => 80
    },
    %{
      "action" => "$N横持$w，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 100,
      "attack" => 26,
      "dodge" => -15,
      "parry" => 18,
      "damage" => 20,
      "lvl" => 100
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，化出漫天杖影，杖影把$n裹了起来",
      "force" => 130,
      "attack" => 35,
      "dodge" => 5,
      "parry" => 22,
      "damage" => 27,
      "lvl" => 120
    },
    %{
      "action" => "$N双手和十，躬身一递出$w，只见$w自肘弯飞出，拦腰向$n撞去",
      "force" => 160,
      "attack" => 40,
      "dodge" => -5,
      "parry" => 28,
      "damage" => 30,
      "lvl" => 140
    },
    %{
      "action" => "$N大喝一声，手中$w如飞龙般自掌中跃出，直向$n的胸口穿入",
      "force" => 180,
      "attack" => 52,
      "dodge" => -5,
      "parry" => 35,
      "damage" => 35,
      "lvl" => 160
    }
  ]

  @impl true
  def id(), do: "guyue-chan"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 guyue-chan.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "staff" ->
        {:error, "你使用的武器不对。\n"}

      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你的内力修为不足，无法学习孤月铲法。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅，无法学习孤月铲法。\n"}

      Stats.skill(stats, "staff") < 20 ->
        {:error, "你的基本杖法太浅，无法学习孤月铲法。\n"}

      Stats.skill(stats, "staff") < Stats.skill(stats, "poshui-zhang") ->
        {:error, "你的基本杖法水平有限，无法领会更高深的孤月铲法。\n"}

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
    %{"jing" => Kantele.Combat.Skills.Performs.GuyueChan.Jing}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

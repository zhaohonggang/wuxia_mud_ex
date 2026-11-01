defmodule Kantele.Combat.Skills.FurongJian do
  @moduledoc """
  芙蓉剑法（对照 `kungfu/skill/furong-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/furong_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求持剑、max_neili>=300、未合 wushen-jian，
    本版以 force>=100 代理；
  - LPC `main_skill("wushen-jian")` 合成用法未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w“嗖”地递出，突然间半空挽出一个剑花，正是一招「芙蓉花开」\n不知不觉间，$w已经向$n的$l刺去",
      "force" => 45,
      "attack" => 10,
      "dodge" => 18,
      "parry" => 20,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w一抖，发出嗡嗡之声，向$n眼睛刺去，但是$w在半路忽地一转\n竟向$n$l刺去，正是芙蓉剑法中的「花开花谢」",
      "force" => 90,
      "attack" => 24,
      "dodge" => 28,
      "parry" => 40,
      "damage" => 35,
      "lvl" => 25,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N不理会对方攻势来路，手中$w刷的一剑「泉鸣芙蓉」，向$n$l刺去",
      "force" => 110,
      "attack" => 30,
      "dodge" => 32,
      "parry" => 40,
      "damage" => 40,
      "lvl" => 50,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w倏地刺出，剑势穿插迂回，如梦如幻，正是一招「花香四溢」，向\n$n$l刺去",
      "force" => 120,
      "attack" => 35,
      "dodge" => 50,
      "parry" => 42,
      "damage" => 48,
      "lvl" => 75,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w倏地刺出，极尽诡奇之能事，动向无定，不可捉摸。正是一招\n「借花献佛」指向$n$l",
      "force" => 150,
      "attack" => 55,
      "dodge" => 75,
      "parry" => 60,
      "damage" => 60,
      "lvl" => 100,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N飞身跃起，一式「芙蓉出水」$w发出一声龙吟从半空中刺向$n的$l",
      "force" => 180,
      "attack" => 65,
      "dodge" => 85,
      "parry" => 68,
      "damage" => 70,
      "lvl" => 120,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "furong-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 furong-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "wushen-jian") > 0 ->
        {:error, "你已演练合成了衡山五神剑，不必再单独学习。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够，没有办法练芙蓉剑法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 60 ->
        {:error, "你的基本剑法火候不够，无法学习芙蓉剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的芙蓉剑法。\n"}

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
    %{"luan" => Kantele.Combat.Skills.Performs.FurongJian.Luan}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

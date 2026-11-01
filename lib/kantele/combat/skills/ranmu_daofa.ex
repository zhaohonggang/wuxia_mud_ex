defmodule Kantele.Combat.Skills.RanmuDaofa do
  @moduledoc """
  燃木刀法（对照 `kungfu/skill/ranmu-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/ranmu_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=2000 与「必须持刀」门槛本版省略
    （max_neili 以 force>=250 代理；持刀判断引擎 `valid_learn/1`
    只拿 stats 无从查询装备）；
  - LPC 招式表与 `practice_skill` 未建模（`query_action` 返回空、
    `practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N面带微笑，一招「烈火烧身」，举$w对着$n连砍了八八六十四刀，刀气纵横，迅雷不可挡",
      "force" => 231,
      "attack" => 31,
      "dodge" => 1,
      "parry" => 2,
      "damage" => 94,
      "lvl" => 0
    },
    %{
      "action" => "$N仰天长笑，施展出一招「天火燎原」，顿时幻出数柄$w同时斩向$n",
      "force" => 263,
      "attack" => 37,
      "dodge" => 12,
      "parry" => 3,
      "damage" => 151,
      "lvl" => 30
    },
    %{
      "action" => "$N腾身飞跃，越过$n头顶，一招「烈焰焚心」，手中$w直劈而下，斩向$n$l",
      "force" => 251,
      "attack" => 31,
      "dodge" => 9,
      "parry" => 4,
      "damage" => 189,
      "lvl" => 100
    },
    %{
      "action" => "$N运起内功一招「点木生火」，$w上带着无比劲气，划了一个大弧，从上而下劈向$n的$l",
      "force" => 242,
      "attack" => 28,
      "dodge" => 16,
      "parry" => 7,
      "damage" => 207,
      "lvl" => 120
    },
    %{
      "action" => "$N手臂一沉，一招「张弓望月」，双手持$w划出一道雪亮刀光，接着拦腰反切，砍向$n的$l",
      "force" => 263,
      "attack" => 33,
      "dodge" => 11,
      "parry" => 9,
      "damage" => 219,
      "lvl" => 140
    },
    %{
      "action" => "$N挥舞$w上劈下撩，左挡右开，使出一招「烈火腾云」，卷起阵阵刀风，齐齐罩向$n",
      "force" => 289,
      "attack" => 31,
      "dodge" => 17,
      "parry" => 13,
      "damage" => 237,
      "lvl" => 160
    },
    %{
      "action" => "$N一招「火中取栗」，左脚跃步落地，手中$w单刀往前，挟着炙热的风声劈向$n的$l",
      "force" => 323,
      "attack" => 41,
      "dodge" => 13,
      "parry" => 4,
      "damage" => 261,
      "lvl" => 180
    },
    %{
      "action" => "$N腾空而起，半空中一招「玉石俱焚」，手中$w挥出满天流光般的刀影，向$n的全身卷去",
      "force" => 302,
      "attack" => 34,
      "dodge" => 11,
      "parry" => 7,
      "damage" => 289,
      "lvl" => 200
    }
  ]

  @impl true
  def id(), do: "ranmu-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 ranmu-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "blade" ->
        {:error, "你必须先找一把刀才能练燃木刀法。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力不足，没有办法练燃木刀法，多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 250 ->
        {:error, "你的内功火候太浅，没有办法练燃木刀法。\n"}

      Stats.skill(stats, "blade") < 100 ->
        {:error, "你的基本刀法火候太浅，没有办法练燃木刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平还不够，无法领会更高深的燃木刀法。\n"}

      (Stats.int(stats) < 32) or (Stats.con(stats) < 30) ->
        {:error, "你先天太差，难以领会燃木刀法的要诣。\n"}

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
    %{
      "huo" => Kantele.Combat.Skills.Performs.RanmuDaofa.Huo,
      "zhenyan" => Kantele.Combat.Skills.Performs.RanmuDaofa.Zhenyan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

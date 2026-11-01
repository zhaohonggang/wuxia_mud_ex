defmodule Kantele.Combat.Skills.DuanjiaJian do
  @moduledoc """
  段家剑法（对照 `kungfu/skill/duanjia-jian.c`）

  剑/杖法载体：`valid_enable("sword")`、`valid_enable("staff")`；
  `valid_force` 接受 基本剑法/基本杖法/段家剑法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/duanjia_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=300 / 基本剑法>=30 门槛本版以 force 等级代理；
  - LPC `practice_skill` 训练（qi 45 / neili 36）未建模（`practice_cost` 返回 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N向前跨上一步，一招「云横秦岭」，手中$w自左向右向$n的$l缓缓划去",
      "force" => 90,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 0,
      "skill_name" => "云横秦岭"
    },
    %{
      "action" => "$N向上跃起，左手剑诀，右手一抖，$w剑光缦妙如瀑，一式「飞流直下」直刺$n的$l",
      "force" => 120,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 20,
      "skill_name" => "飞流直下"
    },
    %{
      "action" => "$N一招「雪涌兰关」，$w闪起数道寒光，自下而上反挑$n的$l",
      "force" => 140,
      "dodge" => 35,
      "damage" => 30,
      "lvl" => 40,
      "skill_name" => "雪涌兰关"
    },
    %{
      "action" => "$N一招「奇兵突起」，手中$w看似横扫实则斜劈，刺向$n的$l",
      "force" => 160,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 60,
      "skill_name" => "奇兵突起"
    },
    %{
      "action" => "$N使出「夜叉探海」，$w挽出三个剑花，绵绵不断划向$n的$l",
      "force" => 180,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 80,
      "skill_name" => "夜叉探海"
    },
    %{
      "action" => "$N一招「泰山压顶」，左手一捏剑诀，右手$w自上而下雷霆万钧般直向$n的$l劈了下去",
      "force" => 210,
      "dodge" => 15,
      "damage" => 60,
      "lvl" => 100,
      "skill_name" => "泰山压顶"
    },
    %{
      "action" => "$N一招「雨打梨花」，身在半空，$w回抽，反手勾向$n的$l",
      "force" => 240,
      "dodge" => 20,
      "damage" => 65,
      "lvl" => 120,
      "skill_name" => "雨打梨花"
    },
    %{
      "action" => "$N身影一晃, 绕到$n背后，一招「逐鹿中原」，剑尖向$n的$l疾挑",
      "force" => 270,
      "dodge" => 25,
      "damage" => 70,
      "lvl" => 140,
      "skill_name" => "逐鹿中原"
    }
  ]

  @impl true
  def id(), do: "duanjia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "staff"]

  @impl true
  def valid_force(force), do: force in ["basic-sword", "basic-staff", "duanjia-jian"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 duanjia-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "sword") < 30 ->
        {:error, "你的基本剑法火候太浅。\n"}

      (Stats.skill(stats, "sword") < lvl) and (Stats.skill(stats, "staff") < lvl) ->
        {:error, "你的基本剑法或杖法火候不够，无法领会更高深的段家剑法。\n"}

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
      "lian" => Kantele.Combat.Skills.Performs.DuanjiaJian.Lian,
      "jing" => Kantele.Combat.Skills.Performs.DuanjiaJian.Jing
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

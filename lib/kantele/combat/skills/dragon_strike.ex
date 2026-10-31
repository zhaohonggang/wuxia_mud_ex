defmodule Kantele.Combat.Skills.DragonStrike do
  @moduledoc """
  武学实装「dragon-strike」（源 dragon-strike.c，由 translate_skill.exs 生成）

  已自动化：静态招式 18 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, skill_improved
  - perform/exert 路由骨架见 tmp/perf_out/dragon_strike/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N双掌平平提到胸前，神色沉重的缓缓施出「亢龙有悔」推向$n的$l",
      "force" => 640,
      "attack" => 220,
      "parry" => 100,
      "dodge" => 10,
      "damage" => 130,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N突然身形飞起，双掌居高临下一招「飞龙在天」拍向$n的$l",
      "force" => 580,
      "attack" => 200,
      "parry" => 80,
      "dodge" => 5,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N右掌一招「见龙在田」，迅捷无比地劈向$n的$l",
      "force" => 520,
      "attack" => 150,
      "parry" => 145,
      "dodge" => 40,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N双掌施出一招「鸿渐于陆」，隐隐带着风声拍向$n的$l",
      "force" => 560,
      "attack" => 180,
      "parry" => 130,
      "dodge" => 15,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N左掌聚成拳状，右掌一招「潜龙勿用」缓缓推向$n的$l",
      "force" => 580,
      "attack" => 190,
      "parry" => 130,
      "dodge" => 10,
      "damage" => 90,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N施出一招「利涉大川」，右掌插腰，左掌劈向$n的$l",
      "force" => 550,
      "attack" => 150,
      "parry" => 180,
      "dodge" => 20,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N使出「突如其来」，右掌从不可能的角度向$n的$l推出",
      "force" => 520,
      "attack" => 160,
      "parry" => 150,
      "dodge" => 40,
      "damage" => 90,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N大吼一声，双掌使出「震惊百里」，不顾一切般击向$n",
      "force" => 690,
      "attack" => 220,
      "parry" => 75,
      "dodge" => -10,
      "damage" => 120,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N使出「或跃在渊」，向$n的$l连拍数掌",
      "force" => 530,
      "attack" => 150,
      "parry" => 140,
      "dodge" => 30,
      "damage" => 140,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N身形滑动，双掌使一招「双龙取水」一前一后按向$n的$l",
      "force" => 560,
      "attack" => 170,
      "parry" => 115,
      "dodge" => 50,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N使出「鱼跃于渊」，身形飞起，双掌并在一起向$n的$l劈下",
      "force" => 550,
      "attack" => 185,
      "parry" => 100,
      "dodge" => 30,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N双掌立起，使出「时乘六龙」向$n连砍六下",
      "force" => 570,
      "attack" => 180,
      "parry" => 110,
      "dodge" => 50,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N使出「密云不雨」，左掌封住$n的退路，右掌斜斜地劈向$l",
      "force" => 560,
      "attack" => 170,
      "parry" => 120,
      "dodge" => 15,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N使出「损则有孚」，双掌软绵绵地拍向$n的$l",
      "force" => 590,
      "attack" => 175,
      "parry" => 100,
      "dodge" => 15,
      "damage" => 80,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N脚下一转，突然欺到$n身前，一招「龙战于野」拍向$n的$l",
      "force" => 580,
      "attack" => 180,
      "parry" => 95,
      "dodge" => 10,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N门户大开，一招「履霜冰至」向$n的$l劈去",
      "force" => 660,
      "attack" => 200,
      "parry" => 90,
      "dodge" => -20,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N使出「羝羊触蕃」，双掌由下往上击向$n的$l",
      "force" => 520,
      "attack" => 160,
      "parry" => 130,
      "dodge" => 40,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N左掌护胸，右掌使一招「神龙摆尾」上下晃动着击向$n的$l",
      "force" => 520,
      "attack" => 150,
      "parry" => 120,
      "dodge" => 60,
      "damage" => 80,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "dragon-strike"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 120, neili: 0}

  # LPC `valid_learn(object me)`（源 dragon-strike.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.str(stats) < 31 ->
        {:error, "就你这身子骨还练降龙十八掌？小心弄折了胳膊。\n"}

      Stats.con(stats) < 24 ->
        {:error, "算了吧，你先天根骨不好，别强学了。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法学习降龙十八掌。\n"}

      not is_nil(max_neili) and max_neili < 1500 ->
        {:error, "你的内力这么差，怎能融会贯通降龙十八掌？\n"}

      Stats.skill(stats, "strike") < 30 ->
        {:error, "你的基本掌法火候不够，无法学习降龙十八掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的降龙十八掌。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "hui" => Kantele.Combat.Skills.Performs.DragonStrike.Hui,
      "lei" => Kantele.Combat.Skills.Performs.DragonStrike.Lei,
      "qin" => Kantele.Combat.Skills.Performs.DragonStrike.Qin,
      "xiang" => Kantele.Combat.Skills.Performs.DragonStrike.Xiang
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

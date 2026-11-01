defmodule Kantele.Combat.Skills.YinhuZhang do
  @moduledoc """
  武学实装「yinhu-zhang」（源 yinhu-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yinhu_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手托住杖端，一招「天上地下」，左掌居中一击，令其凭惯性倒向$n的肩头",
      "force" => 65,
      "attack" => 12,
      "parry" => 5,
      "dodge" => -10,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N双眼发红，将手中$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 89,
      "attack" => 20,
      "parry" => 8,
      "dodge" => -10,
      "damage" => 44,
      "lvl" => 30,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N快步跨出，左手平托$w，右掌猛推杖端，顶向$n的胸口",
      "force" => 128,
      "attack" => 35,
      "parry" => 10,
      "dodge" => -5,
      "damage" => 52,
      "lvl" => 60,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N大喝一声，手中$w如飞龙般自掌中跃出，直向$n的胸口穿入",
      "force" => 200,
      "attack" => 34,
      "parry" => 12,
      "dodge" => -5,
      "damage" => 66,
      "lvl" => 80,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N横持$w，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 250,
      "attack" => 46,
      "parry" => 18,
      "dodge" => -15,
      "damage" => 70,
      "lvl" => 100,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "横持$w，一招「海中求月」，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 280,
      "attack" => 67,
      "parry" => 22,
      "dodge" => 5,
      "damage" => 78,
      "lvl" => 120,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，突出一招「巨浪滔天」，杖影把$n裹了起来",
      "force" => 320,
      "attack" => 89,
      "parry" => 28,
      "dodge" => -5,
      "damage" => 100,
      "lvl" => 140,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N单腿独立，$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 360,
      "attack" => 102,
      "parry" => 35,
      "dodge" => -5,
      "damage" => 120,
      "lvl" => 160,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "yinhu-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 75, neili: 78}

  # LPC `valid_learn(object me)`（源 yinhu-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "staff" ->
        {:error, "你使用的武器不对。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不足，无法学习银瑚杖法。\n"}

      Stats.skill(stats, "force") < 140 ->
        {:error, "你的内功火候太浅，无法学习银瑚杖法。\n"}

      Stats.skill(stats, "staff") < 60 ->
        {:error, "你的基本杖法太浅，无法学习银瑚杖法。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的银瑚杖法。\n"}

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
      "lao" => Kantele.Combat.Skills.Performs.YinhuZhang.Lao
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

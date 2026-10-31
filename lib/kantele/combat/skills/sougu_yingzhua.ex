defmodule Kantele.Combat.Skills.SouguYingzhua do
  @moduledoc """
  武学实装「sougu-yingzhua」（源 sougu-yingzhua.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/sougu_yingzhua/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N全身拔地而起，半空中一个筋斗，一式「鹰飞式」，迅猛地抓向$n的$l",
      "force" => 100,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N单腿直立，双臂平伸，一式「雄鹰式」，双爪一前一后拢向$n的$l",
      "force" => 120,
      "attack" => 40,
      "parry" => 22,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一式「锁骨爪」，全身向斜里平飞，右腿一绷，双爪搭向$n的肩头",
      "force" => 150,
      "attack" => 50,
      "parry" => 28,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双爪交错上举，使一式「夺魂勾」，一拔身，分别袭向$n左右腋空门",
      "force" => 180,
      "attack" => 55,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N全身滚动上前，一式「神鹰式」，右爪突出，鬼魅般抓向$n的胸口",
      "force" => 220,
      "attack" => 65,
      "parry" => 38,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N伏地滑行，一式「血鹰爪」，上手袭向膻中大穴，下手反抓$n的裆部",
      "force" => 240,
      "attack" => 60,
      "parry" => 45,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "sougu-yingzhua"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 67}

  # LPC `valid_learn(object me)`（源 sougu-yingzhua.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练搜骨鹰爪功必须空手。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候不够，无法学搜骨鹰爪功。\n"}

      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力太弱，无法练搜骨鹰爪功。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本抓法火候水平有限，无法领会更高深的搜骨鹰爪功。\n"}

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
      "xue" => Kantele.Combat.Skills.Performs.SouguYingzhua.Xue,
      "ying" => Kantele.Combat.Skills.Performs.SouguYingzhua.Ying
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

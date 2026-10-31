defmodule Kantele.Combat.Skills.YintuoluoZhua do
  @moduledoc """
  武学实装「yintuoluo-zhua」（源 yintuoluo-zhua.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yintuoluo_zhua/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N全身拔地而起，半空中一个筋斗，一式「鹰飞式」，迅猛地抓向$n的$l",
      "force" => 200,
      "attack" => 80,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N单腿直立，双臂平伸，一式「雄鹰式」，双爪一前一后拢向$n的$l",
      "force" => 220,
      "attack" => 100,
      "parry" => 50,
      "dodge" => 50,
      "damage" => 110,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一式「锁骨爪」，全身向斜里平飞，右腿一绷，双爪搭向$n的肩头",
      "force" => 250,
      "attack" => 150,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 180,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双爪交错上举，使一式「夺魂勾」，一拔身，分别袭向$n左右腋空门",
      "force" => 280,
      "attack" => 180,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 240,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N全身滚动上前，一式「神鹰式」，右爪突出，鬼魅般抓向$n的胸口",
      "force" => 400,
      "attack" => 180,
      "parry" => 80,
      "dodge" => 60,
      "damage" => 260,
      "lvl" => 150,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N伏地滑行，一式「血鹰爪」，上手袭向膻中大穴，下手反抓$n的裆部",
      "force" => 490,
      "attack" => 160,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 260,
      "lvl" => 180,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "yintuoluo-zhua"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 60}

  # LPC `valid_learn(object me)`（源 yintuoluo-zhua.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练因陀罗爪必须空手。\n"}

      Stats.skill(stats, "buddhism") < 250 ->
        {:error, "你的佛法修为不够，无法学因陀罗爪。\n"}

      Stats.skill(stats, "force") < 250 ->
        {:error, "你的内功火候不够，无法学因陀罗爪。\n"}

      (Stats.dex(stats) < 30) or (Stats.str(stats) < 30) or (Stats.int(stats) < 30) ->
        {:error, "你的先天不够，无法学因陀罗爪。\n"}

      not is_nil(max_neili) and max_neili < 2500 ->
        {:error, "你的内力太弱，无法练因陀罗爪。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本爪法火候水平有限，无法领会更高深的因陀罗爪。\n"}

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
      "chixue" => Kantele.Combat.Skills.Performs.YintuoluoZhua.Chixue
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

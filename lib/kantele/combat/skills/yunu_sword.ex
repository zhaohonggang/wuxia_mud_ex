defmodule Kantele.Combat.Skills.YunuSword do
  @moduledoc """
  武学实装「yunu-sword」（源 yunu-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_effect, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yunu_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「穿针引线」，脚踏中宫，手中$w直指$n$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "穿针引线"
    },
    %{
      "action" => "$N剑随身转，一招「天衣无缝」，撒出一片剑影，罩向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "天衣无缝"
    },
    %{
      "action" => "$N舞动$w，使出一招「夜绣鸳鸯」剑光忽左忽右，闪烁不定，直刺$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "夜绣鸳鸯"
    },
    %{
      "action" => "$N一声娇喝，祭出「织女穿梭」，手中$w化为一道弧光，射向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "织女穿梭"
    },
    %{
      "action" => "$N忽然蹂身直上，一招「小鸟依人」，手中$w自下往上刺向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "小鸟依人"
    }
  ]

  @impl true
  def id(), do: "yunu-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 1}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end

end

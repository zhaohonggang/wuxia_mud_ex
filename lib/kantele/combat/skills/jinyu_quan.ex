defmodule Kantele.Combat.Skills.JinyuQuan do
  @moduledoc """
  武学实装「jinyu-quan」（源 jinyu-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jinyu_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「金光灿烂」，双拳一上一下, 向$n挥去",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "金光灿烂"
    },
    %{
      "action" => "$N一招「其利断金」，幻出一片拳影，气势如虹，击向$n的头部",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "其利断金"
    },
    %{
      "action" => "$N身影向上飘起，脸浮微笑，一招「蓝田美玉」，轻轻拍向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "蓝田美玉"
    },
    %{
      "action" => "$N一招「金玉其外」，双拳一合，$n只觉到处是$N的拳影",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "金玉其外"
    },
    %{
      "action" => "$N满场游走，拳出如风，不绝击向$n，正是一招「金玉满堂」",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "金玉满堂"
    },
    %{
      "action" => "只见$N一个侧身退步，迅如崩雷，一招「点石成金」击向$n的前胸",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "点石成金"
    },
    %{
      "action" => "$N一招「众口铄金」，扑向$n，似乎$n的全身都被拳影笼罩",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "众口铄金"
    }
  ]

  @impl true
  def id(), do: "jinyu-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 21}

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


  @impl true
  def perform_list() do
    %{
      "man" => Kantele.Combat.Skills.Performs.JinyuQuan.Man
    }
  end
end

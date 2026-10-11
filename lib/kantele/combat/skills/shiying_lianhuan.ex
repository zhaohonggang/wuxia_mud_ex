defmodule Kantele.Combat.Skills.ShiyingLianhuan do
  @moduledoc """
  武学实装「shiying-lianhuan」（源 shiying-lianhuan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shiying_lianhuan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w斜指，一招「回身诛杀势」，反身一顿，一刀向$n的$l撩去",
      "force" => 72,
      "attack" => 16,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "回身诛杀势"
    },
    %{
      "action" => "$N一招「临图现匕势」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 90,
      "attack" => 24,
      "parry" => 40,
      "dodge" => 30,
      "damage" => 21,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "临图现匕势"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「下步劈山势」，刀锋一卷，拦腰斩向$n",
      "force" => 124,
      "attack" => 29,
      "parry" => 45,
      "dodge" => 35,
      "damage" => 35,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "下步劈山势"
    },
    %{
      "action" => "$N一招「戮妖降魔势」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 136,
      "attack" => 34,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 52,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "戮妖降魔势"
    },
    %{
      "action" => "$N手中$w一沉，一招「破玉穿梭势」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 158,
      "attack" => 37,
      "parry" => 55,
      "dodge" => 50,
      "damage" => 65,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "破玉穿梭势"
    },
    %{
      "action" => "$N挥舞$w，使出一招「抱月藏刀势」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 169,
      "attack" => 46,
      "parry" => 55,
      "dodge" => 65,
      "damage" => 73,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "抱月藏刀势"
    },
    %{
      "action" => "$N一招「寒星凸起势」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 210,
      "attack" => 55,
      "parry" => 85,
      "dodge" => 75,
      "damage" => 85,
      "lvl" => 130,
      "damage_type" => "割伤",
      "skill_name" => "寒星凸起势"
    },
    %{
      "action" => "$N盘身驻地，一招「翻天弑穹势」，挥出一片流光般的刀影，向$n的全身涌去",
      "force" => 240,
      "attack" => 76,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 104,
      "lvl" => 160,
      "damage_type" => "割伤",
      "skill_name" => "翻天弑穹势"
    },
    %{
      "action" => "$N回首施出一招「十二转破神势」，$w顿时卷起无数闪耀的刀芒笼罩$n全身",
      "force" => 240,
      "attack" => 76,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 104,
      "lvl" => 200,
      "damage_type" => "割伤",
      "skill_name" => "十二转破神势"
    }
  ]

  @impl true
  def id(), do: "shiying-lianhuan"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 53}

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
      "sha" => Kantele.Combat.Skills.Performs.ShiyingLianhuan.Sha
    }
  end
end

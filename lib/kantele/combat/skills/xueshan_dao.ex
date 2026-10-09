defmodule Kantele.Combat.Skills.XueshanDao do
  @moduledoc """
  武学实装「xueshan-dao」（源 xueshan-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xueshan_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w斜指，一招「风回雪舞」，反身一顿，一刀向$n的$l撩去",
      "force" => 20,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "风回雪舞"
    },
    %{
      "action" => "$N一招「大雪纷飞」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 30,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 30,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "大雪纷飞"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「飞雪飘零」，刀锋一卷，拦腰斩向$n",
      "force" => 40,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 35,
      "damage" => 11,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "飞雪飘零"
    },
    %{
      "action" => "$N一招「梅雪争春」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 60,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 36,
      "damage" => 17,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "梅雪争春"
    },
    %{
      "action" => "$N手中$w一沉，一招「阴风怒号」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 80,
      "attack" => 0,
      "parry" => 35,
      "dodge" => 34,
      "damage" => 21,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "阴风怒号"
    },
    %{
      "action" => "$N挥舞$w，使出一招「雪海茫茫」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 90,
      "attack" => 0,
      "parry" => 38,
      "dodge" => 41,
      "damage" => 27,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "雪海茫茫"
    }
  ]

  @impl true
  def id(), do: "xueshan-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 43}

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

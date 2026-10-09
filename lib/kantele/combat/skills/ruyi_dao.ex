defmodule Kantele.Combat.Skills.RuyiDao do
  @moduledoc """
  武学实装「ruyi-dao」（源 ruyi-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/ruyi_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w斜指，一招「阴晴不定」，反身一顿，一刀向$n的$l撩去",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "阴晴不定"
    },
    %{
      "action" => "$N一招「李白醉酒」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 5,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "李白醉酒"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「推窗望月」，刀锋一卷，拦腰斩向$n",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N一招「所向披靡」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "所向披靡"
    },
    %{
      "action" => "$N手中$w一沉，一招「临溪观鱼」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "临溪观鱼"
    },
    %{
      "action" => "$N挥舞$w，使出一招「张弓望的」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "张弓望的"
    },
    %{
      "action" => "$N一招「扬帆远去」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "扬帆远去"
    },
    %{
      "action" => "$N盘身驻地，一招「川流不息」，挥出一片流光般的刀影，向$n的全身涌去",
      "force" => 310,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "割伤",
      "skill_name" => "川流不息"
    }
  ]

  @impl true
  def id(), do: "ruyi-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 53}

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

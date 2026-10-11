defmodule Kantele.Combat.Skills.WuhuDuanmendao do
  @moduledoc """
  武学实装「wuhu-duanmendao」（源 wuhu-duanmendao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuhu_duanmendao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w斜指，一招「直来直去」，反身一顿，一刀向$n的$l撩去",
      "force" => 30,
      "attack" => 65,
      "parry" => 5,
      "dodge" => -10,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "直来直去"
    },
    %{
      "action" => "$N一招「壁上挂画」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 35,
      "attack" => 65,
      "parry" => 10,
      "dodge" => -10,
      "damage" => 0,
      "lvl" => 10,
      "damage_type" => "割伤",
      "skill_name" => "壁上挂画"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「推窗望月」，刀锋一卷，拦腰斩向$n",
      "force" => 40,
      "attack" => 65,
      "parry" => 5,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N一招「力劈华山」，$w大开大阖，自上而下划出一个闪电，直劈向$n",
      "force" => 60,
      "attack" => 65,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "力劈华山"
    },
    %{
      "action" => "$N手中$w一沉，一招「临溪观鱼」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 80,
      "attack" => 65,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "临溪观鱼"
    },
    %{
      "action" => "$N挥舞$w，使出一招「张弓望的」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 100,
      "attack" => 70,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "割伤",
      "skill_name" => "张弓望的"
    },
    %{
      "action" => "$N一招「风送轻舟」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 110,
      "attack" => 75,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "劈伤",
      "skill_name" => "风送轻舟"
    },
    %{
      "action" => "$N盘身驻地，一招「川流不息」，挥出一片流光般的刀影，向$n的全身涌去",
      "force" => 130,
      "attack" => 80,
      "parry" => 10,
      "dodge" => 20,
      "damage" => 55,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "川流不息"
    },
    %{
      "action" => "$N右手后撤，手腕一翻，一招「壮士断腕」，顿时一道白光直斩向$n的手臂",
      "force" => 150,
      "attack" => 85,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 65,
      "lvl" => 80,
      "damage_type" => "砍伤",
      "skill_name" => "壮士断腕"
    },
    %{
      "action" => "$N高高跃起，一招「人头落地」，手中$w直劈向$n的颈部",
      "force" => 170,
      "attack" => 90,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 75,
      "lvl" => 90,
      "damage_type" => "劈伤",
      "skill_name" => "人头落地"
    },
    %{
      "action" => "$N贴地滑行，一招「断子绝孙」，手中$w直撩去$n的裆部",
      "force" => 180,
      "attack" => 95,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 85,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "断子绝孙"
    }
  ]

  @impl true
  def id(), do: "wuhu-duanmendao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 18}

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
      "duan" => Kantele.Combat.Skills.Performs.WuhuDuanmendao.Duan
    }
  end
end

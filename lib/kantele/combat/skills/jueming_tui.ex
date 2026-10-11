defmodule Kantele.Combat.Skills.JuemingTui do
  @moduledoc """
  武学实装「jueming-tui」（源 jueming-tui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jueming_tui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左脚猛地飞起，一式「盘古开天」，脚尖踢向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "盘古开天"
    },
    %{
      "action" => "$N左脚顿地，右脚一式「流星赶月」，猛踹$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 15,
      "damage_type" => "瘀伤",
      "skill_name" => "流星赶月"
    },
    %{
      "action" => "$N两臂舒张，右脚横踢，既猛且准，一式「横扫千军」踢向$n",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "横扫千军"
    },
    %{
      "action" => "$N突然跃起，双足连环圈转，一式「百步穿杨」，攻向$n的全身",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "百步穿杨"
    },
    %{
      "action" => "$N双脚交叉踢起，一式「川流不息」，脚脚不离$n的面门左右",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "川流不息"
    },
    %{
      "action" => "$N一个侧身，右脚自上而下「独踹华山」，照$n的面门直劈下来",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 45,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "独踹华山"
    },
    %{
      "action" => "$N使一式「夸父追日」，双足忽前忽后，迅猛无及踹向$n的胸口",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "夸父追日"
    },
    %{
      "action" => "$N开声吐气，大喝一声，一式「惊天动地」，双脚猛地踢向$n的$l",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "惊天动地"
    }
  ]

  @impl true
  def id(), do: "jueming-tui"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 51}

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
      "jue" => Kantele.Combat.Skills.Performs.JuemingTui.Jue
    }
  end
end

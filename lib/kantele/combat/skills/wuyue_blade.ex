defmodule Kantele.Combat.Skills.WuyueBlade do
  @moduledoc """
  武学实装「wuyue-blade」（源 wuyue-blade.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuyue_blade/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w轻挥，一招「冬去春来」，身形一转，一刀向$n的$l撩去",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "冬去春来"
    },
    %{
      "action" => "$N一招「月上西楼」，左脚虚点，$w一收一推，平刃挥向$n的脸部",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 8,
      "lvl" => 10,
      "damage_type" => "割伤",
      "skill_name" => "月上西楼"
    },
    %{
      "action" => "$N虚步侧身，一招「推窗望月」，刀锋一卷，拦腰斩向$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N一招「梦断巫山」，$w自上而下划出一个大弧，笔直劈向$n",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 34,
      "damage_type" => "割伤",
      "skill_name" => "梦断巫山"
    },
    %{
      "action" => "$N侧步拧身，一招「似是而非」，拦腰反切，$w砍向$n的胸口",
      "force" => 270,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 45,
      "damage_type" => "割伤",
      "skill_name" => "似是而非"
    },
    %{
      "action" => "$N挥舞$w，使出一招「月挂中天」，幻起片片刀影，齐齐罩向$n",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 60,
      "lvl" => 59,
      "damage_type" => "割伤",
      "skill_name" => "月挂中天"
    },
    %{
      "action" => "$N一招「日月交辉」，只见漫天刀光闪烁，重重刀影向$n的全身涌去",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 90,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "日月交辉"
    }
  ]

  @impl true
  def id(), do: "wuyue-blade"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 61}

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

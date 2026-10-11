defmodule Kantele.Combat.Skills.YinfengDao do
  @moduledoc """
  武学实装「yinfeng-dao」（源 yinfeng-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yinfeng_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形急晃，一跃而至$n跟前，右掌带着切骨寒气砍向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "切骨寒气"
    },
    %{
      "action" => "$N飞身跃起，双掌至上而下斜砍而出，顿时万千道阴风寒劲从四面八方席卷$n",
      "force" => 220,
      "attack" => 40,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "阴风寒劲"
    },
    %{
      "action" => "$N平掌为刀，斜斜砍出，掌劲幻出一片片切骨寒气如飓风般裹向$n的全身",
      "force" => 280,
      "attack" => 50,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 28,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "切骨寒气"
    },
    %{
      "action" => "$N反转右掌对准自己护住全身，突然一个筋斗翻至$n面前，左掌横向$n拦腰砍去",
      "force" => 360,
      "attack" => 60,
      "parry" => 60,
      "dodge" => 80,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "反转右掌"
    },
    %{
      "action" => "$N右掌后撤，手腕一翻，猛地挥掌砍出，幻出一道寒芒直斩向$n的$l",
      "force" => 420,
      "attack" => 110,
      "parry" => 40,
      "dodge" => 45,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "寒芒直斩"
    }
  ]

  @impl true
  def id(), do: "yinfeng-dao"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 80}

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
      "jue" => Kantele.Combat.Skills.Performs.YinfengDao.Jue
    }
  end
end

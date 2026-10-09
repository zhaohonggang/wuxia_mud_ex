defmodule Kantele.Combat.Skills.ChixinJian do
  @moduledoc """
  武学实装「chixin-jian」（源 chixin-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 16 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/chixin_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一式",
      "force" => 50,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "情投意合展欢颜"
    },
    %{
      "action" => "$N使一式",
      "force" => 70,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 5,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "突来横祸阴阳隔"
    },
    %{
      "action" => "$N使一式",
      "force" => 75,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "朝朝暮暮频思忆"
    },
    %{
      "action" => "$N使一式",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "千里婵娟只是空"
    },
    %{
      "action" => "$N使一式",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "生生世世长相伴"
    },
    %{
      "action" => "$N使一式",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "却恨天公不作美"
    },
    %{
      "action" => "$N使一式",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "聚日无多相思苦"
    },
    %{
      "action" => "$N使一式",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "此恨绵绵无绝期"
    },
    %{
      "action" => "$N使一式",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "黯然神伤泪满面"
    },
    %{
      "action" => "$N使一式",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "愿人长久空遗恨"
    },
    %{
      "action" => "$N使一式",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "今世未能偕白头"
    },
    %{
      "action" => "$N使一式",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 50,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "来生还盼续前缘"
    },
    %{
      "action" => "$N使一式",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 65,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "此情不移坚似钢"
    },
    %{
      "action" => "$N使一式",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 60,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "质问天公不开眼"
    },
    %{
      "action" => "$N使一式",
      "force" => 310,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 70,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "痴痴伤怀动情时"
    },
    %{
      "action" => "$N倾尽全力舞出",
      "force" => 320,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 80,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "但舞痴心情长剑"
    }
  ]

  @impl true
  def id(), do: "chixin-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 55}

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

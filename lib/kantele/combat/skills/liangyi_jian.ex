defmodule Kantele.Combat.Skills.LiangyiJian do
  @moduledoc """
  武学实装「liangyi-jian」（源 liangyi-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/liangyi_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N剑尖剑芒暴长，一招「法分玄素」，手中$w自左下大开大阖，",
      "force" => 60,
      "attack" => 15,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "法分玄素"
    },
    %{
      "action" => "$N剑势圈转，手中$w如粘带连，平平展展挥出，一招「道尽阴",
      "force" => 90,
      "attack" => 20,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "道尽阴阳"
    },
    %{
      "action" => "$N长剑轻灵跳动，剑随身长，右手$w使出一式「渊临深浅」刺向",
      "force" => 110,
      "attack" => 20,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "渊临深浅"
    },
    %{
      "action" => "$N长剑下指，剑意流转，一招「水泛青黄」直取$n的$l",
      "force" => 140,
      "attack" => 30,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "水泛青黄"
    },
    %{
      "action" => "$N剑芒吞吐，幻若灵蛇，右手$w使出一式「云含吞吐」，剑势极",
      "force" => 160,
      "attack" => 30,
      "parry" => 40,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "云含吞吐"
    },
    %{
      "action" => "$N屈腕云剑，剑光如彩碟纷飞，幻出点点星光，右手$w使出一式",
      "force" => 190,
      "attack" => 35,
      "parry" => 40,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "梦醒蝶庄"
    },
    %{
      "action" => "$N挥剑分击，剑势自胸前跃出，右手$w一式「人在遐迩」，毫无",
      "force" => 210,
      "attack" => 50,
      "parry" => 40,
      "dodge" => 15,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "人在遐迩"
    },
    %{
      "action" => "$N退步，左手剑指划转，腰部一扭，右手$w一记「情系短长」自下",
      "force" => 240,
      "attack" => 60,
      "parry" => 50,
      "dodge" => 35,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "情系短长"
    }
  ]

  @impl true
  def id(), do: "liangyi-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 25}

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

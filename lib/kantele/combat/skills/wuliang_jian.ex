defmodule Kantele.Combat.Skills.WuliangJian do
  @moduledoc """
  武学实装「wuliang-jian」（源 wuliang-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuliang_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N面露微笑，手中$w一抖，一招「德无量」，剑光暴长，洒向$n的$l",
      "force" => 50,
      "attack" => 15,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "德无量"
    },
    %{
      "action" => "$N身形突闪，剑招陡变，一招「心无量」，手中$w从左位反刺$n的$l",
      "force" => 70,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 25,
      "damage" => 5,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "心无量"
    },
    %{
      "action" => "$N一招「缘无量」，暴退数尺，低首抚剑，随后手中$w骤然穿上，刺向$n的$l",
      "force" => 75,
      "attack" => 33,
      "parry" => 32,
      "dodge" => 22,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "缘无量"
    },
    %{
      "action" => "$N身形一晃疾掠而上，手中$w龙吟一声，一招「大海无量」，对准$n$l连递数剑",
      "force" => 90,
      "attack" => 39,
      "parry" => 35,
      "dodge" => 40,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "大海无量"
    },
    %{
      "action" => "$N一招「天地无量」扑向$n，如影相随，手中$w“铮”然有声，往$n的$l刺去",
      "force" => 100,
      "attack" => 43,
      "parry" => 40,
      "dodge" => 60,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "天地无量"
    },
    %{
      "action" => "$N一个侧身，一招「日月无量」，手中$w疾往斜上挑起，直指$n的$l",
      "force" => 130,
      "attack" => 51,
      "parry" => 45,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "日月无量"
    },
    %{
      "action" => "$N微微一个转身，手中$w却已自肋下穿出，一招「乾坤无量」，罩向$n的$l",
      "force" => 150,
      "attack" => 62,
      "parry" => 47,
      "dodge" => 40,
      "damage" => 30,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "乾坤无量"
    }
  ]

  @impl true
  def id(), do: "wuliang-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 30}

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
      "qian" => Kantele.Combat.Skills.Performs.WuliangJian.Qian
    }
  end
end

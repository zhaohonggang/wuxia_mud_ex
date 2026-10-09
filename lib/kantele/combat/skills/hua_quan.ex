defmodule Kantele.Combat.Skills.HuaQuan do
  @moduledoc """
  武学实装「hua-quan」（源 hua-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/hua_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "只见$N身形一矮，大喝声中一个「斜身拦门插铁闩」对准$n呼地砸去",
      "force" => 60,
      "attack" => 20,
      "parry" => 5,
      "dodge" => 40,
      "damage" => 4,
      "lvl" => 0,
      "damage_type" => "砸伤",
      "skill_name" => "斜身拦门插铁闩"
    },
    %{
      "action" => "$N左手一分，右拳运气，一招「晓星当头即走拳」便往$n的$l招呼过去",
      "force" => 80,
      "attack" => 25,
      "parry" => 6,
      "dodge" => 43,
      "damage" => 7,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "晓星当头即走拳"
    },
    %{
      "action" => "$N右拳在$n面门一晃，左掌使了个「出势跨虎西岳传」往$n狠命一拳",
      "force" => 100,
      "attack" => 28,
      "parry" => 8,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "抓伤",
      "skill_name" => "出势跨虎西岳传"
    },
    %{
      "action" => "$N左拳拉开，右拳带风，一招「金鹏展翅庭中站」势不可挡地击向$n",
      "force" => 120,
      "attack" => 35,
      "parry" => 11,
      "dodge" => 47,
      "damage" => 17,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "金鹏展翅庭中站"
    },
    %{
      "action" => "只见$N拉开架式，一招「韦陀献抱在胸前」使出，底下却飞踢$n的$l",
      "force" => 140,
      "attack" => 40,
      "parry" => 13,
      "dodge" => 49,
      "damage" => 20,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "韦陀献抱在胸前"
    },
    %{
      "action" => "$N左手往$n身后一抄，一招「把臂拦门横铁闩」便往$n面门砸去",
      "force" => 160,
      "attack" => 45,
      "parry" => 16,
      "dodge" => 52,
      "damage" => 22,
      "lvl" => 120,
      "damage_type" => "砸伤",
      "skill_name" => "把臂拦门横铁闩"
    },
    %{
      "action" => "$N拉开后弓步，双掌使了个「魁鬼仰斗撩绿栏」往$n的$l狠力一推",
      "force" => 200,
      "attack" => 48,
      "parry" => 18,
      "dodge" => 54,
      "damage" => 28,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "魁鬼仰斗撩绿栏"
    },
    %{
      "action" => "只见$N运足气力使出「出势跨虎西岳传」，连攻数拳，全部击向$n的$l",
      "force" => 220,
      "attack" => 51,
      "parry" => 20,
      "dodge" => 57,
      "damage" => 32,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "出势跨虎西岳传"
    },
    %{
      "action" => "$N往后一纵，就势使了个「白猿偷桃拜天庭」，右腿扫向$n的$l",
      "force" => 260,
      "attack" => 55,
      "parry" => 21,
      "dodge" => 61,
      "damage" => 35,
      "lvl" => 180,
      "damage_type" => "砸伤",
      "skill_name" => "白猿偷桃拜天庭"
    },
    %{
      "action" => "$N一个转身，左掌护胸，右掌反手使了个「吴王试剑劈玉砖」往$n当头劈落",
      "force" => 280,
      "attack" => 60,
      "parry" => 23,
      "dodge" => 63,
      "damage" => 37,
      "lvl" => 200,
      "damage_type" => "砸伤",
      "skill_name" => "吴王试剑劈玉砖"
    },
    %{
      "action" => "$N飞身跃起，一招「撤身倒步一溜烟」，脚踢$n面门，随即双拳已到$n$l",
      "force" => 300,
      "attack" => 62,
      "parry" => 25,
      "dodge" => 65,
      "damage" => 40,
      "lvl" => 220,
      "damage_type" => "瘀伤",
      "skill_name" => "撤身倒步一溜烟"
    }
  ]

  @impl true
  def id(), do: "hua-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 40}

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

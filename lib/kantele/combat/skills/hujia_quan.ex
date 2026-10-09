defmodule Kantele.Combat.Skills.HujiaQuan do
  @moduledoc """
  武学实装「hujia-quan」（源 hujia-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/hujia_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "只见$N身形一矮，大喝声中一个「冲天炮」对准$n的鼻子呼地砸去",
      "force" => 60,
      "attack" => 20,
      "parry" => 5,
      "dodge" => 40,
      "damage" => 4,
      "lvl" => 0,
      "damage_type" => "砸伤",
      "skill_name" => "冲天炮"
    },
    %{
      "action" => "$N左手一分，右拳运气，一招「拔草寻蛇」便往$n的$l招呼过去",
      "force" => 80,
      "attack" => 25,
      "parry" => 6,
      "dodge" => 43,
      "damage" => 7,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "拔草寻蛇"
    },
    %{
      "action" => "$N右拳在$n面门一晃，左掌使了个「叶底偷桃」往$n的$l狠命一抓",
      "force" => 100,
      "attack" => 28,
      "parry" => 8,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "抓伤",
      "skill_name" => "叶底偷桃"
    },
    %{
      "action" => "$N左拳拉开，右拳带风，一招「黑虎掏心」势不可挡地击向$n$l",
      "force" => 120,
      "attack" => 35,
      "parry" => 11,
      "dodge" => 47,
      "damage" => 17,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "黑虎掏心"
    },
    %{
      "action" => "只见$N拉开架式，一招「双风贯耳」使出，底下却飞起一脚踢向$n$l",
      "force" => 140,
      "attack" => 40,
      "parry" => 13,
      "dodge" => 49,
      "damage" => 20,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "双风贯耳"
    },
    %{
      "action" => "$N大喝一声，左手往$n身后一抄，右拳便往$n面门砸了过去",
      "force" => 160,
      "attack" => 45,
      "parry" => 16,
      "dodge" => 52,
      "damage" => 22,
      "lvl" => 120,
      "damage_type" => "砸伤",
      "skill_name" => "龙虎相交"
    },
    %{
      "action" => "$N拉开后弓步，双掌使了个「如封似闭」往$n的$l一推",
      "force" => 200,
      "attack" => 48,
      "parry" => 18,
      "dodge" => 54,
      "damage" => 28,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "如封似闭"
    },
    %{
      "action" => "只见$N运足气力，一连三拳击向$n$l，力道一拳高过一拳",
      "force" => 220,
      "attack" => 51,
      "parry" => 20,
      "dodge" => 57,
      "damage" => 32,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "阳关三叠"
    },
    %{
      "action" => "$N往后一纵，就势使了个「老树盘根」，右腿扫向$n的$l",
      "force" => 260,
      "attack" => 55,
      "parry" => 21,
      "dodge" => 61,
      "damage" => 35,
      "lvl" => 180,
      "damage_type" => "砸伤",
      "skill_name" => "老树盘根"
    },
    %{
      "action" => "$N一个转身，左掌护胸，右掌反手使了个「独劈华山」往$n当头一劈",
      "force" => 280,
      "attack" => 60,
      "parry" => 23,
      "dodge" => 63,
      "damage" => 37,
      "lvl" => 200,
      "damage_type" => "砸伤",
      "skill_name" => "独劈华山"
    },
    %{
      "action" => "$N飞身跃起，一招「苍鹰捕鼠」，脚踢$n面门，随即双拳已到$n的$l",
      "force" => 300,
      "attack" => 62,
      "parry" => 25,
      "dodge" => 65,
      "damage" => 40,
      "lvl" => 220,
      "damage_type" => "瘀伤",
      "skill_name" => ""
    }
  ]

  @impl true
  def id(), do: "hujia-quan"

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

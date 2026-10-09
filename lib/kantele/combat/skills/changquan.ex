defmodule Kantele.Combat.Skills.Changquan do
  @moduledoc """
  武学实装「changquan」（源 changquan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/changquan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "只见$N身形一矮，大喝声中一个「冲天炮」对准$n鼻子呼地砸了去",
      "force" => 90,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤",
      "skill_name" => "冲天炮"
    },
    %{
      "action" => "$N左手一分，右拳运气，一招「拔草寻蛇」便往$n的$l招呼过去",
      "force" => 60,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "拔草寻蛇"
    },
    %{
      "action" => "$N右拳在$n面门一晃，左掌使了个「叶底偷桃」往$n的$l狠命一抓",
      "force" => 60,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "叶底偷桃"
    },
    %{
      "action" => "$N步履一沉，左拳拉开，右拳带风，一招「黑虎掏心」击向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "黑虎掏心"
    },
    %{
      "action" => "$N拉开架式，一招「双风贯耳」使得虎虎有风。底下却一脚踢向$n",
      "force" => 70,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "双风贯耳"
    },
    %{
      "action" => "$N拉开后弓步，双掌使了个「如封似闭」往$n的$l一推",
      "force" => 50,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "如封似闭"
    },
    %{
      "action" => "$N往后一纵，就势使了个「老树盘根」，右腿扫向$n的$l",
      "force" => 50,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤",
      "skill_name" => "老树盘根"
    },
    %{
      "action" => "$N转身左掌护胸，右掌反手使了个「独劈华山」往$n当头一劈",
      "force" => 90,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤",
      "skill_name" => "独劈华山"
    }
  ]

  @impl true
  def id(), do: "changquan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 50}

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

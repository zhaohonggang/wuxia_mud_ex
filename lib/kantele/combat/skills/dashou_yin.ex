defmodule Kantele.Combat.Skills.DashouYin do
  @moduledoc """
  武学实装「dashou-yin」（源 dashou-yin.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dashou_yin/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「莲花合掌印」，双掌合十，直直撞向$n的前胸",
      "force" => 120,
      "attack" => 25,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "莲花合掌印"
    },
    %{
      "action" => "$N使出一招「合掌观音印」，飞身跃起，双手如勾，抓向$n的$l",
      "force" => 170,
      "attack" => 30,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "合掌观音印"
    },
    %{
      "action" => "$N使出一招「准提佛母印」，运力于指，直取$n的$l",
      "force" => 220,
      "attack" => 35,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "准提佛母印"
    },
    %{
      "action" => "$N使出一招「红阎婆罗印」，怒吼一声，一掌当头拍向$n的$l",
      "force" => 250,
      "attack" => 40,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "红阎婆罗印"
    },
    %{
      "action" => "$N使出一招「药师佛根本印」，猛冲向前，掌如游龙般攻向$n",
      "force" => 280,
      "attack" => 45,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "药师佛根本印"
    },
    %{
      "action" => "$N使出一招「威德金刚印」，伏身疾进，双掌自下扫向$n的$l",
      "force" => 320,
      "attack" => 50,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "威德金刚印"
    },
    %{
      "action" => "$N使出一招「上乐金刚印」，飞身横跃，双掌前后击出，抓向$n的咽",
      "force" => 340,
      "attack" => 55,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "上乐金刚印"
    },
    %{
      "action" => "$N使出一招「六臂智慧印」，顿时劲气弥漫，天空中出现无数掌影打",
      "force" => 360,
      "attack" => 65,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "六臂智慧印"
    }
  ]

  @impl true
  def id(), do: "dashou-yin"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 61}

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

defmodule Kantele.Combat.Skills.ShouYin do
  @moduledoc """
  武学实装「shou-yin」（源 shou-yin.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shou_yin/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「莲花合掌印」，双掌做锥，直直刺向$n的前胸",
      "force" => 589,
      "attack" => 285,
      "parry" => 189,
      "dodge" => 167,
      "damage" => 303,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「合掌观音印」，飞身跃起，双手如勾，抓向$n的$l",
      "force" => 621,
      "attack" => 309,
      "parry" => 197,
      "dodge" => 188,
      "damage" => 326,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「准提佛母印」，运力于指，直取$n的$l",
      "force" => 642,
      "attack" => 321,
      "parry" => 203,
      "dodge" => 197,
      "damage" => 339,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「红阎婆罗印」，怒吼一声，一掌当头拍向$n的$l",
      "force" => 657,
      "attack" => 335,
      "parry" => 227,
      "dodge" => 215,
      "damage" => 356,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N使出一招「药师佛根本印」，猛冲向前，掌刀如游龙般砍向$n",
      "force" => 673,
      "attack" => 357,
      "parry" => 236,
      "dodge" => 243,
      "damage" => 367,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N使出一招「威德金刚印」，伏身疾进，双掌自下扫向$n的$l",
      "force" => 672,
      "attack" => 371,
      "parry" => 257,
      "dodge" => 265,
      "damage" => 386,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N使出一招「上乐金刚印」，飞身横跃，双掌前后击出，抓向$n的咽",
      "force" => 680,
      "attack" => 398,
      "parry" => 271,
      "dodge" => 297,
      "damage" => 403,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「六臂智慧印」，顿时劲气弥漫，天空中出现无数掌影打",
      "force" => 720,
      "attack" => 435,
      "parry" => 287,
      "dodge" => 315,
      "damage" => 436,
      "lvl" => 0,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "shou-yin"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 300, neili: 300}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "jie" => Kantele.Combat.Skills.Performs.ShouYin.Jie
    }
  end
end

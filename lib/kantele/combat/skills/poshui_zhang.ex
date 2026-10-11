defmodule Kantele.Combat.Skills.PoshuiZhang do
  @moduledoc """
  武学实装「poshui-zhang」（源 poshui-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/poshui_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N纵步上前，手中$w自下而上，沉猛无比地向$n的小腹挑去",
      "force" => 35,
      "attack" => 8,
      "parry" => 5,
      "dodge" => -10,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N快步跨出，左手平托$w，右掌猛推杖端，顶向$n的胸口",
      "force" => 50,
      "attack" => 10,
      "parry" => 8,
      "dodge" => -10,
      "damage" => 8,
      "lvl" => 30,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N高举$w，全身跃起，手中$w朝着$n头盖天灵盖猛然击落下去",
      "force" => 65,
      "attack" => 15,
      "parry" => 10,
      "dodge" => -5,
      "damage" => 12,
      "lvl" => 60,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N双手持杖如橹，对准$n猛地一搅，如同平地刮起一阵旋风",
      "force" => 80,
      "attack" => 18,
      "parry" => 12,
      "dodge" => -5,
      "damage" => 15,
      "lvl" => 80,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N横持$w，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 100,
      "attack" => 26,
      "parry" => 18,
      "dodge" => -15,
      "damage" => 20,
      "lvl" => 100,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，化出漫天杖影，杖影把$n裹了起来",
      "force" => 130,
      "attack" => 35,
      "parry" => 22,
      "dodge" => 5,
      "damage" => 27,
      "lvl" => 120,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N双手和十，躬身一递出$w，只见$w自肘弯飞出，拦腰向$n撞去",
      "force" => 160,
      "attack" => 40,
      "parry" => 28,
      "dodge" => -5,
      "damage" => 30,
      "lvl" => 140,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N大喝一声，手中$w如飞龙般自掌中跃出，直向$n的胸口穿入",
      "force" => 180,
      "attack" => 52,
      "parry" => 35,
      "dodge" => -5,
      "damage" => 35,
      "lvl" => 160,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "poshui-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 75, neili: 78}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "tai" => Kantele.Combat.Skills.Performs.PoshuiZhang.Tai
    }
  end
end

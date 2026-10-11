defmodule Kantele.Combat.Skills.PuduZhang do
  @moduledoc """
  武学实装「pudu-zhang」（源 pudu-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pudu_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「黄牛转角」，手中$w自下而上，沉猛无比地向$n的小腹挑去。",
      "force" => 180,
      "attack" => 24,
      "parry" => 10,
      "dodge" => -10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "黄牛转角"
    },
    %{
      "action" => "$N快步跨出，一招「野马追风」，左手平托$w，右掌猛推杖端，顶向$n的胸口。",
      "force" => 200,
      "attack" => 36,
      "parry" => 19,
      "dodge" => -10,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "挫伤",
      "skill_name" => "野马追风"
    },
    %{
      "action" => "$N高举$w，一招「猛虎跳涧」，全身跃起，手中$w搂头盖顶地向$n击去。",
      "force" => 230,
      "attack" => 42,
      "parry" => 25,
      "dodge" => -5,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "挫伤",
      "skill_name" => "猛虎跳涧"
    },
    %{
      "action" => "$N一招「狮子摇头」，双手持杖如橹，对准$n猛地一搅，如同平地刮起一阵旋风。",
      "force" => 270,
      "attack" => 51,
      "parry" => 30,
      "dodge" => -5,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "狮子摇头"
    },
    %{
      "action" => "$N横持$w，一招「苍龙摆尾」，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中。",
      "force" => 320,
      "attack" => 64,
      "parry" => 40,
      "dodge" => -15,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "挫伤",
      "skill_name" => "苍龙摆尾"
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，突出一招「大蟒翻身」，杖影把$n裹了起来",
      "force" => 350,
      "attack" => 68,
      "parry" => 42,
      "dodge" => 5,
      "damage" => 35,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "大蟒翻身"
    },
    %{
      "action" => "$N双手和十，躬身一招「胡僧托钵」，$w自肘弯飞出，拦腰向$n撞去。",
      "force" => 380,
      "attack" => 70,
      "parry" => 52,
      "dodge" => -5,
      "damage" => 40,
      "lvl" => 140,
      "damage_type" => "挫伤",
      "skill_name" => "胡僧托钵"
    },
    %{
      "action" => "$N一招「慈航普渡」，$w如飞龙般自掌中跃出，直向$n的胸口穿入。",
      "force" => 410,
      "attack" => 72,
      "parry" => 60,
      "dodge" => -5,
      "damage" => 45,
      "lvl" => 160,
      "damage_type" => "挫伤",
      "skill_name" => "慈航普渡"
    }
  ]

  @impl true
  def id(), do: "pudu-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 68}

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
      "zhao" => Kantele.Combat.Skills.Performs.PuduZhang.Zhao
    }
  end
end

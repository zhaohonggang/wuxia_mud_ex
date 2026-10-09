defmodule Kantele.Combat.Skills.HengshanSword do
  @moduledoc """
  武学实装「hengshan-sword」（源 hengshan-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/hengshan_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手$w慢慢指出，突然间在空中一颤，发出嗡嗡之声，跟着便是",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 17,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "星夜寒光"
    },
    %{
      "action" => "$N手中$w如鬼如魅，竟然已绕到了$n背后，$n急忙转身，耳边只听",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 22,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "云气初现"
    },
    %{
      "action" => "$N手中$w寒光陡闪，手中的$w，猛地反刺，直指$n胸口。这一下",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 29,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "百变千幻"
    },
    %{
      "action" => "$N不理会对方攻势来路，手中$w刷的一剑「泉鸣芙蓉」，向$n小",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "泉鸣芙蓉"
    },
    %{
      "action" => "$N不理会对方攻势来路，手中$w刷的一剑「鹤翔紫盖」，向$n额",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 4,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "鹤翔紫盖"
    },
    %{
      "action" => "$N手中$w倏地刺出，剑势穿插迂回，如梦如幻，正是一招「石廪书声」，",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "石廪书声"
    },
    %{
      "action" => "$N手中$w倏地刺出，极尽诡奇之能事，动向无定，不可捉摸。正是",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "天柱云气"
    },
    %{
      "action" => "$N飞身跃起，『雁回祝融』！，$w发出一声龙吟从半空中洒向$n的$l",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "雁回祝融"
    }
  ]

  @impl true
  def id(), do: "hengshan-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 18}

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

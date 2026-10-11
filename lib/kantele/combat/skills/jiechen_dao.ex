defmodule Kantele.Combat.Skills.JiechenDao do
  @moduledoc """
  武学实装「jiechen-dao」（源 jiechen-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jiechen_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N内息转动，运劲于单刀，全身骨节一阵暴响，起手一式「示诞生」向$n劈出，将$n全身笼罩在赤热的刀风下",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "示诞生"
    },
    %{
      "action" => "$N面带轻笑，一招「始心镜」，火焰刀内劲由内及外慢慢涌出，$P双掌如宝像合十于胸前，向着$n深深一鞠",
      "force" => 350,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "震伤",
      "skill_name" => "始心镜"
    },
    %{
      "action" => "$N刀掌相合又打开，这招「现宝莲」以火焰刀无上功力聚出一朵红莲，盛开的花瓣飞舞旋转，漫布在$n四周",
      "force" => 400,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "割伤",
      "skill_name" => "现宝莲"
    },
    %{
      "action" => "$N面带金刚相，刀气搓圆，使无数炙热的刀气相聚，这招「破法执」犹如一只巨大的飞鹰，凌空向$n飞抓而下",
      "force" => 340,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 1,
      "damage" => 0,
      "lvl" => 70,
      "damage_type" => "内伤",
      "skill_name" => "破法执"
    },
    %{
      "action" => "$N暴喝一声，竟然使出伏魔无上的「开显圆」，气浪如飓风般围着$P飞旋，炎流将$n一步步向着$P拉扯过来",
      "force" => 450,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 0,
      "lvl" => 120,
      "damage_type" => "震伤",
      "skill_name" => "开显圆"
    },
    %{
      "action" => "$N口念伏魔真经，钢刀连连劈出，将$n笼罩在炙焰之下，这如刀切斧凿般的「显真常」气浪似乎要将$p从中劈开",
      "force" => 380,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 140,
      "damage_type" => "割伤",
      "skill_name" => "显真常"
    },
    %{
      "action" => "$N现宝相，结迦兰，右手「归真法」单刀挥出，半空中刀气凝结不散，但发出炙灼的气浪却排山倒海般地涌向$n",
      "force" => 450,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -15,
      "damage" => 0,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "归真法"
    },
    %{
      "action" => "$N虚托刀柄，一式「吉祥逝」，内力运转，跟着全身衣物无风自动，$P身体微倾，闪电一刀，斩向$n$",
      "force" => 500,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 180,
      "damage_type" => "割伤",
      "skill_name" => "吉祥逝"
    }
  ]

  @impl true
  def id(), do: "jiechen-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 35}

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
      "xiuluo" => Kantele.Combat.Skills.Performs.JiechenDao.Xiuluo
    }
  end
end

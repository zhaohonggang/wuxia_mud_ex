defmodule Kantele.Combat.Skills.QixingQuan do
  @moduledoc """
  武学实装「qixing-quan」（源 qixing-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qixing_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「星光灿烂」，双拳闪动, 攻向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 2,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "星光灿烂"
    },
    %{
      "action" => "$N一招「摇光易位」，一拳横扫，气势如虹，击向$n的$l",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 12,
      "damage" => 5,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "摇光易位"
    },
    %{
      "action" => "$N身影向飘动，脸浮微笑，一招「星过长空」，右拳快速拍向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 16,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "星过长空"
    },
    %{
      "action" => "$N一招「群星闪烁」，双拳数分数合，$n只觉到处是$N的拳影",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 18,
      "damage" => 22,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "群星闪烁"
    },
    %{
      "action" => "$N施展开「千变万化」绕着$n一转，飞身游走，拳出如风，不住的击向$n。",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 21,
      "damage" => 26,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "千变万化"
    },
    %{
      "action" => "只见$N突然猛跨两步，已到$n面前，右拳陡出，迅如崩雷，",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 22,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "点石成金"
    },
    %{
      "action" => "$N一招「北斗生采」，拳影交错，上中下一齐攻向$n。",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "北斗生采"
    }
  ]

  @impl true
  def id(), do: "qixing-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 36, neili: 18}

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

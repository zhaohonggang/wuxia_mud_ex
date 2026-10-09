defmodule Kantele.Combat.Skills.XieweiBian do
  @moduledoc """
  武学实装「xiewei-bian」（源 xiewei-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiewei_bian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N单手一扬，一招「天蝎爪」，手中$w抖得笔直，直点$n的双眼",
      "force" => 100,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 12,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N力贯鞭梢，一招「蝎尾钩」，手中$w舞出满天鞭影，横扫$n腰间",
      "force" => 130,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 17,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N运气于腕，一招「毒蝎蚀月」，手中$w向一根铜棍般直击$n胸部",
      "force" => 150,
      "attack" => 0,
      "parry" => 19,
      "dodge" => 21,
      "damage" => 13,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N单臂一挥，一招「蛇游蝎行」，手中$w直击向$n腰肋",
      "force" => 175,
      "attack" => 0,
      "parry" => 27,
      "dodge" => 32,
      "damage" => 18,
      "lvl" => 60,
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N高高跃起，一招「天蝎藏针」，手中$w笔直向$n当头刺下",
      "force" => 225,
      "attack" => 0,
      "parry" => 37,
      "dodge" => 42,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "xiewei-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 50}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

defmodule Kantele.Combat.Skills.LeitingFu do
  @moduledoc """
  武学实装「leiting-fu」（源 leiting-fu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/leiting_fu/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N立定当地，手中的$w在面前移动，突然一招「春雷炸空」向$n劈去",
      "force" => 320,
      "attack" => 27,
      "parry" => -34,
      "dodge" => -30,
      "damage" => 62,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "春雷炸空"
    },
    %{
      "action" => "$N渊停岳峙，身形猛的升起五丈，一招「飞惊落虹」寒光乍现般向$n劈去",
      "force" => 460,
      "attack" => 38,
      "parry" => -45,
      "dodge" => -27,
      "damage" => 66,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "飞惊落虹"
    },
    %{
      "action" => "$N突然暴喝一声，手里的$w一挫，一招「苍穹开破」猛的劈向$n而去",
      "force" => 500,
      "attack" => 43,
      "parry" => -47,
      "dodge" => -25,
      "damage" => 70,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "苍穹开破"
    },
    %{
      "action" => "$N斜移两步，手中$w发出阵阵寒光，陡然间一招「破碎虚空」劈向$n",
      "force" => 520,
      "attack" => 51,
      "parry" => -50,
      "dodge" => -45,
      "damage" => 75,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "破碎虚空"
    },
    %{
      "action" => "$N双手一顿，一招「火雨流星」，手中的$w以极快的速度向$n连劈数下",
      "force" => 530,
      "attack" => 55,
      "parry" => -25,
      "dodge" => -20,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "挫伤",
      "skill_name" => "火雨流星"
    },
    %{
      "action" => "$N将$w舞得尤如万条金龙，使人不敢靠近，猛的一招「魂冥千屠」向$n劈去",
      "force" => 550,
      "attack" => 65,
      "parry" => -35,
      "dodge" => -40,
      "damage" => 98,
      "lvl" => 180,
      "damage_type" => "挫伤",
      "skill_name" => "魂冥千屠"
    },
    %{
      "action" => "$N手中的$w“铛”的一声，斧锋侧翻，光铧骤闪，一招「绝寰电闪」劈向$n",
      "force" => 570,
      "attack" => 84,
      "parry" => -33,
      "dodge" => -62,
      "damage" => 104,
      "lvl" => 220,
      "damage_type" => "挫伤",
      "skill_name" => "绝寰电闪"
    },
    %{
      "action" => "$N斧尖指天，斧锋骤颤，陡然施出一招「泣血惊天」，数十道冷光劈向$n",
      "force" => 580,
      "attack" => 97,
      "parry" => -33,
      "dodge" => -62,
      "damage" => 113,
      "lvl" => 260,
      "damage_type" => "挫伤",
      "skill_name" => "泣血惊天"
    },
    %{
      "action" => "$N突然一招「创刃无还」，手中的$w像是穹苍中的一道闪电般劈向$n",
      "force" => 610,
      "attack" => 109,
      "parry" => -33,
      "dodge" => -62,
      "damage" => 121,
      "lvl" => 280,
      "damage_type" => "挫伤",
      "skill_name" => "创刃无还"
    },
    %{
      "action" => "$N一越拔空，长啸仿如龙吟，施一招「天外归星」，$w犹如一个光球劈向$n",
      "force" => 640,
      "attack" => 130,
      "parry" => -33,
      "dodge" => -62,
      "damage" => 134,
      "lvl" => 300,
      "damage_type" => "挫伤",
      "skill_name" => "天外归星"
    }
  ]

  @impl true
  def id(), do: "leiting-fu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 150}

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

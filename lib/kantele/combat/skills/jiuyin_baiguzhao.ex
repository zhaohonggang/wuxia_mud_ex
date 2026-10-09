defmodule Kantele.Combat.Skills.JiuyinBaiguzhao do
  @moduledoc """
  武学实装「jiuyin-baiguzhao」（源 jiuyin-baiguzhao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jiuyin_baiguzhao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左爪虚晃，右爪蓄力，一招「勾魂夺魄」直插向$n的$l",
      "force" => 250,
      "attack" => 45,
      "parry" => 18,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "勾魂夺魄"
    },
    %{
      "action" => "$N双手连环成爪，爪爪钩向$n，「九子连环」已向$n的$l抓出",
      "force" => 270,
      "attack" => 50,
      "parry" => 26,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "九子连环"
    },
    %{
      "action" => "$N双手使出「十指穿心」，招招不离$n的$l",
      "force" => 300,
      "attack" => 60,
      "parry" => 32,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "抓伤",
      "skill_name" => "九子连环"
    },
    %{
      "action" => "$N身形围$n一转，使出「天罗地网」，$n的$l已完全笼罩在爪影下",
      "force" => 340,
      "attack" => 85,
      "parry" => 55,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "抓伤",
      "skill_name" => "天罗地网"
    },
    %{
      "action" => "$N使一招「风卷残云」，双爪幻出满天爪影抓向$n全身",
      "force" => 370,
      "attack" => 110,
      "parry" => 68,
      "dodge" => 40,
      "damage" => 70,
      "lvl" => 130,
      "damage_type" => "抓伤",
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N吐气扬声，一招「唯我独尊」双爪奋力向$n天灵戳下",
      "force" => 420,
      "attack" => 140,
      "parry" => 85,
      "dodge" => 50,
      "damage" => 90,
      "lvl" => 160,
      "damage_type" => "抓伤",
      "skill_name" => "唯我独尊"
    }
  ]

  @impl true
  def id(), do: "jiuyin-baiguzhao"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 250}

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

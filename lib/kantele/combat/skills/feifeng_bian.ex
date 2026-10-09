defmodule Kantele.Combat.Skills.FeifengBian do
  @moduledoc """
  武学实装「feifeng-bian」（源 feifeng-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/feifeng_bian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N向上跃起，一招「凤凰展翅」，手中$w自下而上，击向$n的脸颊",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 20,
      "lvl" => 15,
      "damage_type" => "刮伤",
      "skill_name" => "凤凰展翅"
    },
    %{
      "action" => "$N一招「彩凤栖梧」，手中$w腾空一卷，直绕向$n的$l而去",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "彩凤栖梧"
    },
    %{
      "action" => "$N一招「鸾凤和鸣」，手中$w腾空一卷，一声脆响，猛地向$n劈头打下",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -15,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "劈伤",
      "skill_name" => "鸾凤和鸣"
    },
    %{
      "action" => "$N踏上一步，手中$w毫不停留，一招「游龙戏凤」，扫向$n的$l",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -30,
      "damage" => 60,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "游龙戏凤"
    },
    %{
      "action" => "$N半空一招「龙飞凤舞」，手中$w如游龙洗空，长凤戏羽，分点$n左右",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -35,
      "damage" => 70,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "龙飞凤舞"
    },
    %{
      "action" => "$N向前急进，手中$w圈转如虹，一招「龙凤呈祥」，罩向$n前胸",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -40,
      "damage" => 85,
      "lvl" => 75,
      "damage_type" => "内伤",
      "skill_name" => "龙凤呈祥"
    }
  ]

  @impl true
  def id(), do: "feifeng-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 39}

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

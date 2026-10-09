defmodule Kantele.Combat.Skills.LongzhuaGong do
  @moduledoc """
  武学实装「longzhua-gong」（源 longzhua-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/longzhua_gong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N使一招「捕风式」，双手如钩如戢，插向$n的$l",
      "force" => 100,
      "attack" => 30,
      "parry" => 5,
      "dodge" => 25,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "捕风式"
    },
    %{
      "action" => "$N猛地向前跃出，一招「捉影式」，两腿踢出，双手抓向$n的面门",
      "force" => 110,
      "attack" => 41,
      "parry" => 5,
      "dodge" => 30,
      "damage" => 20,
      "lvl" => 10,
      "damage_type" => "内伤",
      "skill_name" => "捉影式"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，一招「抚琴式」打向$n的$l",
      "force" => 120,
      "attack" => 49,
      "parry" => 10,
      "dodge" => 35,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "抚琴式"
    },
    %{
      "action" => "$N左手上拦，右手内挥，一招「击鼓式」击向$n胸口",
      "force" => 140,
      "attack" => 54,
      "parry" => 11,
      "dodge" => 36,
      "damage" => 30,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "击鼓式"
    },
    %{
      "action" => "$N右手虚握，左手掌立如山，一招「批亢式」，猛地击向$n的$l",
      "force" => 160,
      "attack" => 57,
      "parry" => 15,
      "dodge" => 38,
      "damage" => 40,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "批亢式"
    },
    %{
      "action" => "$N腾步上前，左手护胸，右手探出，一招「掏虚式」击向$n的裆部",
      "force" => 190,
      "attack" => 60,
      "parry" => 19,
      "dodge" => 42,
      "damage" => 45,
      "lvl" => 50,
      "damage_type" => "内伤",
      "skill_name" => "掏虚式"
    },
    %{
      "action" => "$N双手平提胸前，左手护住面门，一招「抱残式」右手推向$n的$l",
      "force" => 220,
      "attack" => 65,
      "parry" => 21,
      "dodge" => 47,
      "damage" => 51,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "抱残式"
    },
    %{
      "action" => "$N两手胸前环抱，腋下含空，五指如钩，一招「守缺式」插向$n的顶门",
      "force" => 260,
      "attack" => 71,
      "parry" => 22,
      "dodge" => 52,
      "damage" => 54,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "守缺式"
    },
    %{
      "action" => "$N右腿斜插$n二腿之间，一招「抢珠式」，上手取目，下手反勾$n的裆部",
      "force" => 300,
      "attack" => 76,
      "parry" => 25,
      "dodge" => 55,
      "damage" => 57,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "抢珠式"
    },
    %{
      "action" => "$N一手虚指$n的剑诀，一招「夺剑式」，一手劈空抓向$n手中的长剑",
      "force" => 320,
      "attack" => 82,
      "parry" => 31,
      "dodge" => 61,
      "damage" => 62,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "夺剑式"
    },
    %{
      "action" => "$N左手指向$n胸前的五道大穴，右手斜指太阳穴，一招「拿云式」使",
      "force" => 340,
      "attack" => 85,
      "parry" => 35,
      "dodge" => 62,
      "damage" => 65,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "拿云式"
    },
    %{
      "action" => "$N前脚着地，一手顶天成爪，一手指地，一招「追日式」劲气笼罩$n",
      "force" => 360,
      "attack" => 90,
      "parry" => 38,
      "dodge" => 65,
      "damage" => 70,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "追日式"
    }
  ]

  @impl true
  def id(), do: "longzhua-gong"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 69}

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

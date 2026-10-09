defmodule Kantele.Combat.Skills.YunlongShou do
  @moduledoc """
  武学实装「yunlong-shou」（源 yunlong-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yunlong_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「草木皆兵」，十指伸缩，虚虚实实地袭向$n的全身要穴",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "草木皆兵"
    },
    %{
      "action" => "在呼呼风声中，$N使一招「捕风捉影」，双手如钩如戢，插向$n的$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "捕风捉影"
    },
    %{
      "action" => "$N双拳挥舞，一式「浮云去来」，两手环扣，拢成圈状，猛击$n的下颌",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "浮云去来"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，一招「十指乾坤」打向$n的$l",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "十指乾坤"
    },
    %{
      "action" => "$N左手护胸，腋下含空，右手五指如钩，一招「抱残守缺」插向$n的顶门",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "抱残守缺"
    },
    %{
      "action" => "$N右腿斜插$n二腿之间，一招「掏虚抢珠」，上手取目，下手反勾$n的裆部",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "掏虚抢珠"
    },
    %{
      "action" => "$N一手虚指$n的剑诀，一招「空手入刃」，劈空抓向$n手中的兵刃",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 45,
      "lvl" => 130,
      "damage_type" => "抓伤",
      "skill_name" => "空手入刃"
    },
    %{
      "action" => "$N左手指向$n胸前的五道大穴，右手斜指太阳穴，一招「降龙伏虎」使$n进退两难",
      "force" => 230,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "降龙伏虎"
    },
    %{
      "action" => "$N一手顶天成爪，一手指地，一招「拨云见日」,劲气笼罩$n的全身",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 55,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "拨云见日"
    },
    %{
      "action" => "$N一式「如烟往事」，拳招若隐若现，若有若无，缓缓地拍向$n的丹田",
      "force" => 270,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 60,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "如烟往事"
    },
    %{
      "action" => "$N随意挥洒，使一式「我心依旧」，掌心微红,徐徐拍向$n的$l",
      "force" => 290,
      "attack" => 0,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 70,
      "lvl" => 170,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "yunlong-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 62, neili: 59}

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

defmodule Kantele.Combat.Skills.QujingGunfa do
  @moduledoc """
  武学实装「qujing-gunfa」（源 qujing-gunfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qujing_gunfa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形稍退，一招「大闹阎罗府」，手中$w迎风一抖，朝着$n劈头盖脸地砸将下",
      "force" => 289,
      "attack" => 31,
      "parry" => 35,
      "dodge" => 31,
      "damage" => 34,
      "lvl" => 0,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N仰天长笑，看也不看，一招「谈笑退天兵」，随手一棒向$n当头砸下",
      "force" => 316,
      "attack" => 37,
      "parry" => 42,
      "dodge" => 33,
      "damage" => 41,
      "lvl" => 25,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N一个虎跳，越过$n头顶，一招「勇斗二郎神」，手中$w抡个大圆，砸向$n$l",
      "force" => 318,
      "attack" => 38,
      "parry" => 35,
      "dodge" => 38,
      "damage" => 73,
      "lvl" => 50,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N一声巨喝，一招「脱困老君炉」！$n一愣之间，$N手中$w已呼啸而至，扫向$n的$l",
      "force" => 331,
      "attack" => 48,
      "parry" => 33,
      "dodge" => 31,
      "damage" => 91,
      "lvl" => 75,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N身形稍退，一招「大闹阎罗府」，手中$w迎风一抖，朝着$n劈头盖脸地砸将下",
      "force" => 391,
      "attack" => 63,
      "parry" => 31,
      "dodge" => 49,
      "damage" => 103,
      "lvl" => 100,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N使出「醉闹蟠桃会」，脚步跄踉，左一棒，右一棒，打得$n手忙脚乱，招架不迭",
      "force" => 481,
      "attack" => 74,
      "parry" => 28,
      "dodge" => 51,
      "damage" => 167,
      "lvl" => 130,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N连翻几个筋斗，使出「三打白骨精」，手中$w转得如风车一般，一连三棒直击$n顶门",
      "force" => 503,
      "attack" => 83,
      "parry" => 35,
      "dodge" => 31,
      "damage" => 184,
      "lvl" => 160,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N一招「千钧澄玉宇」，手中$w化为万道霞光，乘$n目眩之时，$w已到了$n的$l",
      "force" => 548,
      "attack" => 108,
      "parry" => 51,
      "dodge" => 43,
      "damage" => 213,
      "lvl" => 200,
      "damage_type" => "砸伤"
    }
  ]

  @impl true
  def id(), do: "qujing-gunfa"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 120, neili: 100}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "zhen" => Kantele.Combat.Skills.Performs.QujingGunfa.Zhen
    }
  end
end

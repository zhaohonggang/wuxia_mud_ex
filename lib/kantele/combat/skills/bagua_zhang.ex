defmodule Kantele.Combat.Skills.BaguaZhang do
  @moduledoc """
  武学实装「bagua-zhang」（源 bagua-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/bagua_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左肩低，右肩高，左手斜，右手正，一式「怀中抱月」，双掌疾推向$n的肩头",
      "force" => 60,
      "attack" => 5,
      "parry" => 5,
      "dodge" => 40,
      "damage" => 2,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "怀中抱月"
    },
    %{
      "action" => "$N先退又进，使招「猛虎伏桩」，左掌切向$n的$l，跟着右掌变拳，直击他前胸",
      "force" => 80,
      "attack" => 11,
      "parry" => 6,
      "dodge" => 43,
      "damage" => 7,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "猛虎伏桩"
    },
    %{
      "action" => "$N身法陡然一变，使出一式「沉肘擒拿」，掌影千变万幻，令$n无法躲闪",
      "force" => 100,
      "attack" => 8,
      "parry" => 8,
      "dodge" => 45,
      "damage" => 6,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "沉肘擒拿"
    },
    %{
      "action" => "$N左掌向外一穿，右掌「游空探爪」斜劈，对准$n的$l拍出一排掌影，隐隐带着风声",
      "force" => 120,
      "attack" => 15,
      "parry" => 11,
      "dodge" => 47,
      "damage" => 11,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "游空探爪"
    },
    %{
      "action" => "$N左掌画了个圈圈，暗藏诸多变化，右掌推出，一招「金龙抓爪」直取$n的$l",
      "force" => 140,
      "attack" => 24,
      "parry" => 13,
      "dodge" => 49,
      "damage" => 15,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "金龙抓爪"
    },
    %{
      "action" => "$N左掌突然张开，变掌为爪，直击化为横扫，一招「遁甲擒踪」便往$n的$l招呼过去",
      "force" => 160,
      "attack" => 28,
      "parry" => 18,
      "dodge" => 54,
      "damage" => 18,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "遁甲擒踪"
    },
    %{
      "action" => "$N使出「劈雷坠地」，身形凌空飞起，从空中当头向$n的$l出掌攻击",
      "force" => 190,
      "attack" => 31,
      "parry" => 23,
      "dodge" => 53,
      "damage" => 15,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "劈雷坠地"
    },
    %{
      "action" => "$N前腿踢出，后腿脚尖点地，一式「双打奇门」，二掌直出，双双攻向$n的上中下三路",
      "force" => 210,
      "attack" => 33,
      "parry" => 25,
      "dodge" => 55,
      "damage" => 13,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "双打奇门"
    }
  ]

  @impl true
  def id(), do: "bagua-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 50}

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

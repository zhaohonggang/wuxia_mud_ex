defmodule Kantele.Combat.Skills.TieZhang do
  @moduledoc """
  武学实装「tie-zhang」（源 tie-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tie_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右掌一拂而起，施出「推窗望月」自侧面连消带打，登时将$n力道带斜",
      "force" => 187,
      "attack" => 45,
      "parry" => 32,
      "dodge" => 33,
      "damage" => 38,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N施出「分水擒龙」，左掌陡然沿着伸长的右臂一削而出，斩向$n的$l",
      "force" => 212,
      "attack" => 53,
      "parry" => 45,
      "dodge" => 34,
      "damage" => 43,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N一招「白云幻舞」，双臂如旋风一般一阵狂舞，刮起一阵旋转的气浪",
      "force" => 224,
      "attack" => 67,
      "parry" => 53,
      "dodge" => 45,
      "damage" => 51,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N陡然一招「掌内乾坤」，侧过身来，右臂自左肋下翻出，直拍向$n而去",
      "force" => 251,
      "attack" => 91,
      "parry" => 63,
      "dodge" => 61,
      "damage" => 68,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "掌内乾坤"
    },
    %{
      "action" => "$N一招「落日赶月」，伸掌一拍一收，顿时一股阴柔无比的力道向$n迸去",
      "force" => 297,
      "attack" => 93,
      "parry" => 87,
      "dodge" => 81,
      "damage" => 76,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "落日赶月"
    },
    %{
      "action" => "$N身行暴起，一式「蛰雷为动」，双掌横横向$n切出，呜呜呼啸之声狂作",
      "force" => 310,
      "attack" => 91,
      "parry" => 71,
      "dodge" => 67,
      "damage" => 73,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "蛰雷为动"
    },
    %{
      "action" => "$N一招「天罗地网」，左掌大圈而出，右掌小圈而发，两股力道同时击向$n",
      "force" => 324,
      "attack" => 102,
      "parry" => 68,
      "dodge" => 71,
      "damage" => 85,
      "lvl" => 200,
      "damage_type" => "瘀伤",
      "skill_name" => "天罗地网"
    },
    %{
      "action" => "$N施一招「五指幻山」，单掌有如推门，另一掌却是迅疾无比的一推即收",
      "force" => 330,
      "attack" => 112,
      "parry" => 73,
      "dodge" => 55,
      "damage" => 92,
      "lvl" => 220,
      "damage_type" => "瘀伤",
      "skill_name" => "五指幻山"
    },
    %{
      "action" => "$N突然大吼一声，一招「铁掌神威」，身行疾飞而起，再猛向$n直扑而下",
      "force" => 321,
      "attack" => 123,
      "parry" => 72,
      "dodge" => 73,
      "damage" => 95,
      "lvl" => 240,
      "damage_type" => "瘀伤",
      "skill_name" => "铁掌神威"
    }
  ]

  @impl true
  def id(), do: "tie-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 120, neili: 0}

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

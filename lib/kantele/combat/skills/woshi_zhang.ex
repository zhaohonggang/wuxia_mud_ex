defmodule Kantele.Combat.Skills.WoshiZhang do
  @moduledoc """
  武学实装「woshi-zhang」（源 woshi-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/woshi_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N马步一立，身子微曲，暗喝一声，一招「望月拜天」，一掌直劈$n的$l",
      "force" => 110,
      "attack" => 30,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 40,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "望月拜天"
    },
    %{
      "action" => "$N“哈哈”一笑，左掌由下至上，右掌平平击出，一招「跨日向天」，交替打向$n",
      "force" => 130,
      "attack" => 30,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "跨日向天"
    },
    %{
      "action" => "$N对$n一声大喝，使一招「长虹经天」，左掌击出，随即右掌跟上，两重力道打向$n的$l",
      "force" => 140,
      "attack" => 40,
      "parry" => 43,
      "dodge" => 27,
      "damage" => 60,
      "lvl" => 60,
      "damage_type" => "震伤",
      "skill_name" => "长虹经天"
    },
    %{
      "action" => "$N闷喝一声，双掌向上分开，一记「举火烧天」，掌划弧线，左右同时击向$n的$l",
      "force" => 160,
      "attack" => 54,
      "parry" => 33,
      "dodge" => 37,
      "damage" => 78,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "举火烧天"
    },
    %{
      "action" => "$N施出「一臂擎天」，一声大吼，一掌凌空劈出，掌风直逼$n的$l",
      "force" => 180,
      "attack" => 64,
      "parry" => 23,
      "dodge" => 42,
      "damage" => 89,
      "lvl" => 110,
      "damage_type" => "瘀伤",
      "skill_name" => "一臂擎天"
    },
    %{
      "action" => "$N一声长啸，双掌交错击出，一招「石破天惊」，掌风密布$n的前后左右",
      "force" => 190,
      "attack" => 54,
      "parry" => 33,
      "dodge" => 46,
      "damage" => 93,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "石破天惊"
    },
    %{
      "action" => "$N怒吼一声，凌空飞起，一式「天崩地裂」，双掌居高临下，齐齐拍向$n",
      "force" => 200,
      "attack" => 55,
      "parry" => 43,
      "dodge" => 43,
      "damage" => 103,
      "lvl" => 170,
      "damage_type" => "内伤",
      "skill_name" => "天崩地裂"
    },
    %{
      "action" => "$N仰天大笑，势若疯狂，衣袍飞舞，一招「无法无天」，掌风凌厉，如雨点般向$n",
      "force" => 210,
      "attack" => 58,
      "parry" => 53,
      "dodge" => 33,
      "damage" => 105,
      "lvl" => 190,
      "damage_type" => "内伤",
      "skill_name" => "无法无天"
    }
  ]

  @impl true
  def id(), do: "woshi-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 50}

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


  @impl true
  def perform_list() do
    %{
      "po" => Kantele.Combat.Skills.Performs.WoshiZhang.Po
    }
  end
end

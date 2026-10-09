defmodule Kantele.Combat.Skills.QinnaShibada do
  @moduledoc """
  武学实装「qinna-shibada」（源 qinna-shibada.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qinna_shibada/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N马步一立，身子微曲，暗喝一声，一招「望月拜天」，似爪似拳直捅$n的$l",
      "force" => 170,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "望月拜天"
    },
    %{
      "action" => "$N“哈哈”一笑，左拳由下至上，右手似擒似推，一招「跨日向天」，交替打向$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 5,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 15,
      "damage_type" => "瘀伤",
      "skill_name" => "跨日向天"
    },
    %{
      "action" => "$N对$n一声大喝，使一招「长虹经天」，左拳击出，右脚同时绊向的$l",
      "force" => 230,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "震伤",
      "skill_name" => "长虹经天"
    },
    %{
      "action" => "$N闷喝一声，双拳向上分开，一记「举火烧天」，拳划弧线，左右同时击向$n的$l",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 45,
      "damage_type" => "瘀伤",
      "skill_name" => "举火烧天"
    },
    %{
      "action" => "$N施出「轻臂擎天」，左手凌空打出，直逼$n的$l",
      "force" => 290,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "一臂擎天"
    },
    %{
      "action" => "$N一声长啸，双拳交错击出，一招「石破天惊」，拳风密布$n的前后左右",
      "force" => 310,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "石破天惊"
    },
    %{
      "action" => "$N怒吼一声，凌空飞起，一式「天崩地裂」，双拳居高临下，齐齐捶向$n",
      "force" => 350,
      "attack" => 0,
      "parry" => -10,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "天崩地裂"
    },
    %{
      "action" => "$N仰天大笑，势若疯狂，衣袍飞舞，一招「无法无天」，左擒右拿，如雨点般向$n打去",
      "force" => 380,
      "attack" => 0,
      "parry" => -10,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 90,
      "damage_type" => "内伤",
      "skill_name" => "无法无天"
    }
  ]

  @impl true
  def id(), do: "qinna-shibada"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 35}

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

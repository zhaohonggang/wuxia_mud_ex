defmodule Kantele.Combat.Skills.KunlunZhang do
  @moduledoc """
  武学实装「kunlun-zhang」（源 kunlun-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/kunlun_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双掌骤起，一招「天清云淡」，一掌击向$n面门，另一掌却按向$n小腹",
      "force" => 73,
      "attack" => 9,
      "parry" => 12,
      "dodge" => 11,
      "damage" => 12,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "天清云淡"
    },
    %{
      "action" => "$N双掌互错，变幻莫测，一招「秋风不尽」，瞬息之间向$n攻出了四四一十六招",
      "force" => 95,
      "attack" => 13,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 17,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "秋风不尽"
    },
    %{
      "action" => "$N一声清啸，呼的一掌，一招「山回路转」，去势奇快，向$n的$l猛击过去，",
      "force" => 127,
      "attack" => 17,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 21,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "山回路转"
    },
    %{
      "action" => "$N双掌交错，若有若无，一招「天衣无缝」，自巧转拙，拍向$n的$l",
      "force" => 145,
      "attack" => 22,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 33,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "天衣无缝"
    },
    %{
      "action" => "$N一招「青山断河」，右手一拳击出，左掌紧跟着在右拳上一搭，变成双掌下劈，击向$n的$l",
      "force" => 185,
      "attack" => 33,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 41,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "青山断河"
    },
    %{
      "action" => "$N双手齐划，跟着双掌齐推，一招「北风卷地」，一股排山倒海的掌力，直扑$n面门",
      "force" => 197,
      "attack" => 36,
      "parry" => 30,
      "dodge" => 28,
      "damage" => 49,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "北风卷地"
    },
    %{
      "action" => "$N突然滴溜溜的转身，一招「天山雪飘」，掌影飞舞，霎时之间将$n四面八方都裹住了",
      "force" => 210,
      "attack" => 37,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 51,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "天山雪飘"
    },
    %{
      "action" => "$N仰天大笑，势若疯狂，衣袍飞舞，一招「群山叠影」，掌风凌厉，如雨点般向$n打去",
      "force" => 220,
      "attack" => 41,
      "parry" => 35,
      "dodge" => 36,
      "damage" => 58,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "群山叠影"
    }
  ]

  @impl true
  def id(), do: "kunlun-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 45}

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

defmodule Kantele.Combat.Skills.WuluoZhang do
  @moduledoc """
  武学实装「wuluo-zhang」（源 wuluo-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuluo_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一掌轻出，一招「清风斜雨」直袭$n的$l，了无半点痕迹",
      "force" => 30,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "清风斜雨"
    },
    %{
      "action" => "$N转过身来，正是一招「垂钓江畔」，左脚轻点，右掌挥向$n的脸部",
      "force" => 50,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 5,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "垂钓江畔"
    },
    %{
      "action" => "$N虚步侧身，一招「落叶雅意」，手腕一转，劈向$n",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "落叶雅意"
    },
    %{
      "action" => "$N一招「归路未晓」，双掌化作无数掌影，轻飘飘的拍向$n",
      "force" => 70,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 15,
      "lvl" => 34,
      "damage_type" => "瘀伤",
      "skill_name" => "归路未晓"
    },
    %{
      "action" => "$N一招「春风拂柳」，左掌手指微微张开，拂向$n的手腕",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 20,
      "lvl" => 45,
      "damage_type" => "瘀伤",
      "skill_name" => "春风拂柳"
    },
    %{
      "action" => "$N转身侧头，轻轻一笑，使出一招「逍遥世间」，一掌拍出，仿佛不食半点人间烟火",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 75,
      "damage" => 25,
      "lvl" => 59,
      "damage_type" => "瘀伤",
      "skill_name" => "逍遥世间"
    },
    %{
      "action" => "$N身形飘忽，一招「我心犹怜」，双掌软绵绵的拍向$n",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "我心犹怜"
    }
  ]

  @impl true
  def id(), do: "wuluo-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 13}

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

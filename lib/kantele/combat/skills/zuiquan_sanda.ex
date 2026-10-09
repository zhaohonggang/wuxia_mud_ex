defmodule Kantele.Combat.Skills.ZuiquanSanda do
  @moduledoc """
  武学实装「zuiquan-sanda」（源 zuiquan-sanda.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zuiquan_sanda/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N连续上步，脚下蹒跚，双拳缓缓划向$n的$l",
      "force" => 80,
      "attack" => 12,
      "parry" => 14,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左脚虚踏，全身右转，摆姿扭腰，右臂顺势猛地扫向$n的$l",
      "force" => 100,
      "attack" => 15,
      "parry" => 16,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 8,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身子往前一晃，伸出双掌，指天打地，猛的向$n的$l劈去",
      "force" => 120,
      "attack" => 18,
      "parry" => 19,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 15,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N脚下一个不稳，身子顿时向前一倾，双掌顺势拍出，如闪电一般切向$n",
      "force" => 170,
      "attack" => 23,
      "parry" => 24,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 42,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N摇摇晃晃，偏偏倒倒，可双拳却拳出如风，笼罩着$n头，胸，腹三处要害",
      "force" => 200,
      "attack" => 25,
      "parry" => 24,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N醉眼朦胧，但却举重若轻，一声大喝，喷出一口酒气，单掌挟千钧之力拍向$n",
      "force" => 210,
      "attack" => 28,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 58,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "zuiquan-sanda"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 25, neili: 20}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

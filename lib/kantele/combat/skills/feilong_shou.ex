defmodule Kantele.Combat.Skills.FeilongShou do
  @moduledoc """
  武学实装「feilong-shou」（源 feilong-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/feilong_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N使一招「捕风捉影」，双手如钩如戢，插向$n的$l",
      "force" => 80,
      "attack" => 25,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双拳挥舞，一式「浮云去来」，两手环扣，拢成圈状，猛击$n的下颌",
      "force" => 100,
      "attack" => 28,
      "parry" => 27,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一招「飞龙献爪」，双手纷飞，$n只觉眼花缭乱",
      "force" => 120,
      "attack" => 32,
      "parry" => 28,
      "dodge" => 30,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手护胸，腋下含空，右手五指如钩，一招「抱残守缺」插向$n的顶门",
      "force" => 150,
      "attack" => 33,
      "parry" => 33,
      "dodge" => 30,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一手顶天成爪，一手指地，一招「拨云见日」，劲气笼罩$n的全身",
      "force" => 180,
      "attack" => 36,
      "parry" => 37,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手平举，一招「苍龙出水」，身形化作一道闪电射向$n",
      "force" => 210,
      "attack" => 42,
      "parry" => 45,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一招「云中现爪」，拿向$n，似乎$n的全身都被笼罩",
      "force" => 240,
      "attack" => 47,
      "parry" => 41,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左手虚晃，右手一记「龙飞在天」击向$n的头部",
      "force" => 260,
      "attack" => 46,
      "parry" => 47,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 160,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "feilong-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 62}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

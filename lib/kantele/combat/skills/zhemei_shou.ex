defmodule Kantele.Combat.Skills.ZhemeiShou do
  @moduledoc """
  武学实装「zhemei-shou」（源 zhemei-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhemei_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「吹梅笛怨」，双手横挥，抓向$n",
      "force" => 80,
      "attack" => 25,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "吹梅笛怨"
    },
    %{
      "action" => "$N一招「黄昏独自愁」，身子跃然而起，抓向$n的头部",
      "force" => 100,
      "attack" => 28,
      "parry" => 27,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "黄昏独自愁"
    },
    %{
      "action" => "$N一招「寒山一带伤心碧」，双手纷飞，$n只觉眼花缭乱",
      "force" => 120,
      "attack" => 32,
      "parry" => 28,
      "dodge" => 30,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "寒山一带伤心碧"
    },
    %{
      "action" => "$N一招「梅花雪落覆白苹」，双手合击，$n只觉无处可避",
      "force" => 150,
      "attack" => 33,
      "parry" => 33,
      "dodge" => 30,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "梅花雪落覆白苹"
    },
    %{
      "action" => "$N一招「砌下落梅如雪乱」，双手飘然抓向$n",
      "force" => 180,
      "attack" => 36,
      "parry" => 37,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "砌下落梅如雪乱"
    },
    %{
      "action" => "$N双手平举，一招「云破月来花弄影」击向$n",
      "force" => 210,
      "attack" => 42,
      "parry" => 45,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "云破月来花弄影"
    },
    %{
      "action" => "$N一招「花开堪折直须折」，拿向$n，似乎$n的全身都被笼罩",
      "force" => 240,
      "attack" => 47,
      "parry" => 41,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "花开堪折直须折"
    },
    %{
      "action" => "$N左手虚晃，右手一记「红颜未老恩先绝」击向$n的头部",
      "force" => 280,
      "attack" => 46,
      "parry" => 47,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "红颜未老恩先绝"
    },
    %{
      "action" => "$N施出「虚妄笑红」，右手横扫$n的$l，左手攻向$n的胸口",
      "force" => 330,
      "attack" => 58,
      "parry" => 55,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 170,
      "damage_type" => "瘀伤",
      "skill_name" => "虚妄笑红"
    },
    %{
      "action" => "$N施出「玉石俱焚」，不顾一切扑向$n",
      "force" => 370,
      "attack" => 62,
      "parry" => 52,
      "dodge" => 20,
      "damage" => 80,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "玉石俱焚"
    }
  ]

  @impl true
  def id(), do: "zhemei-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 85, neili: 72}

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

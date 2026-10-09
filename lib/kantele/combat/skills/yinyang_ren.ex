defmodule Kantele.Combat.Skills.YinyangRen do
  @moduledoc """
  武学实装「yinyang-ren」（源 yinyang-ren.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yinyang_ren/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一式「虚式分金」，手中$w由左至右横扫向向$n的$l",
      "force" => 126,
      "attack" => 0,
      "parry" => 3,
      "dodge" => 5,
      "damage" => 21,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "虚式分金"
    },
    %{
      "action" => "$N踏上一步，「荆轲刺秦」，手中$w盘旋飞舞出一道金光劈向$n的$l",
      "force" => 149,
      "attack" => 0,
      "parry" => 13,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "荆轲刺秦"
    },
    %{
      "action" => "$N手中$w一抖，一招「九品莲台」，斜斜反腕撩出，攻向$n的$l",
      "force" => 167,
      "attack" => 0,
      "parry" => 12,
      "dodge" => 15,
      "damage" => 31,
      "lvl" => 50,
      "damage_type" => "割伤",
      "skill_name" => "九品莲台"
    },
    %{
      "action" => "$N手中$w连绕数个大圈，一式「刚柔并济」，一道光飞向$n的$l",
      "force" => 187,
      "attack" => 0,
      "parry" => 23,
      "dodge" => 19,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "刚柔并济"
    },
    %{
      "action" => "$N手中$w斜指苍天，一式「日月无华」，对准$n的$l斜斜击出",
      "force" => 197,
      "attack" => 0,
      "parry" => 31,
      "dodge" => 27,
      "damage" => 56,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "日月无华"
    },
    %{
      "action" => "$N一式「天罡汇聚」，$w飞斩盘旋，如疾电般射向$n的胸口",
      "force" => 218,
      "attack" => 0,
      "parry" => 49,
      "dodge" => 35,
      "damage" => 63,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "天罡汇聚"
    },
    %{
      "action" => "$N手中$w一沉，一式「行影相随」，无声无息地滑向$n的$l",
      "force" => 239,
      "attack" => 0,
      "parry" => 52,
      "dodge" => 45,
      "damage" => 72,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "行影相随"
    },
    %{
      "action" => "$N手中$w斜指苍天，剑芒吞吐，一式「岁月无声」，对准$n的$l斜斜击出",
      "force" => 287,
      "attack" => 0,
      "parry" => 55,
      "dodge" => 51,
      "damage" => 88,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "岁月无声"
    },
    %{
      "action" => "$N左指凌空虚点，右手$w逼出丈许雪亮光芒，一式「流水无情」刺向$n的咽喉",
      "force" => 342,
      "attack" => 0,
      "parry" => 63,
      "dodge" => 55,
      "damage" => 105,
      "lvl" => 170,
      "damage_type" => "刺伤",
      "skill_name" => "流水无情"
    },
    %{
      "action" => "$N合掌跌坐，一式「刀光剑影」，$w自怀中跃出，如疾电般射向$n的胸口",
      "force" => 381,
      "attack" => 0,
      "parry" => 76,
      "dodge" => 65,
      "damage" => 122,
      "lvl" => 190,
      "damage_type" => "刺伤",
      "skill_name" => "刀光剑影"
    }
  ]

  @impl true
  def id(), do: "yinyang-ren"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 100}

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

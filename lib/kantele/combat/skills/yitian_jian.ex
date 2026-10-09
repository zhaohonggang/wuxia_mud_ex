defmodule Kantele.Combat.Skills.YitianJian do
  @moduledoc """
  武学实装「yitian-jian」（源 yitian-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yitian_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N剑尖剑芒暴长，一招「倚天寒芒」，手中$w大开大阖，剑芒直刺$n的$l",
      "force" => 98,
      "attack" => 13,
      "parry" => 3,
      "dodge" => 2,
      "damage" => 41,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "倚天寒芒"
    },
    %{
      "action" => "$N剑芒吞吐，单手$w一招「翻江倒海」，剑势曼妙，剑光直逼向$n的$l",
      "force" => 132,
      "attack" => 19,
      "parry" => 4,
      "dodge" => 3,
      "damage" => 58,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "翻江倒海"
    },
    %{
      "action" => "$N一式「神剑佛威」，屈腕云剑，剑光如彩碟纷飞，幻出点点星光飘向$n",
      "force" => 163,
      "attack" => 23,
      "parry" => 10,
      "dodge" => 9,
      "damage" => 77,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "神剑佛威"
    },
    %{
      "action" => "$N挥剑分击，剑势自胸前跃出，$w一式「群邪辟易」，毫无留恋之势，刺向$n",
      "force" => 190,
      "attack" => 31,
      "parry" => 13,
      "dodge" => 11,
      "damage" => 85,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "群邪辟易"
    },
    %{
      "action" => "$N左手剑指划转，腰部一扭，右手$w一记「荡妖除魔」自下而上刺向$n的$l",
      "force" => 225,
      "attack" => 35,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 93,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "荡妖除魔"
    }
  ]

  @impl true
  def id(), do: "yitian-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 55}

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

defmodule Kantele.Combat.Skills.XuangongQuan do
  @moduledoc """
  武学实装「xuangong-quan」（源 xuangong-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuangong_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「划手」，双手划了个半圈，按向$n的$l",
      "force" => 37,
      "attack" => 5,
      "parry" => 38,
      "dodge" => 35,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "划手"
    },
    %{
      "action" => "$N使一招「单鞭」，右手收置肋下，左手向外挥出，劈向$n的$l",
      "force" => 48,
      "attack" => 7,
      "parry" => 53,
      "dodge" => 51,
      "damage" => 2,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "单鞭"
    },
    %{
      "action" => "$N左手回收，右手由钩变掌，由右向左，使一招「印掌」，向$n的$l打去",
      "force" => 62,
      "attack" => 9,
      "parry" => 57,
      "dodge" => 45,
      "damage" => 3,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "印掌"
    },
    %{
      "action" => "$N双手划弧，右手向上，左手向下，使一招「拗鞭」，分击$n的面门和$l",
      "force" => 74,
      "attack" => 11,
      "parry" => 62,
      "dodge" => 53,
      "damage" => 5,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "拗鞭"
    },
    %{
      "action" => "$N左手由胸前向下，身体微转，划了一个大圈，使一招「摔碑手」，击向$n的$l",
      "force" => 92,
      "attack" => 15,
      "parry" => 88,
      "dodge" => 76,
      "damage" => 8,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "摔碑手"
    },
    %{
      "action" => "$N左手由下上挑，右手内合，使一招「拨云见日」，向$n的$l打去",
      "force" => 120,
      "attack" => 19,
      "parry" => 97,
      "dodge" => 81,
      "damage" => 11,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "拨云见日"
    },
    %{
      "action" => "$N左手变掌横于胸前，右拳由肘下穿出，一招「七星拳」，锤向$n的$l",
      "force" => 152,
      "attack" => 21,
      "parry" => 108,
      "dodge" => 95,
      "damage" => 14,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "七星拳"
    },
    %{
      "action" => "$N左脚前踏半步，右手使一招「海底针」，指由下向$n的$l戳去",
      "force" => 183,
      "attack" => 31,
      "parry" => 113,
      "dodge" => 105,
      "damage" => 17,
      "lvl" => 130,
      "damage_type" => "瘀伤",
      "skill_name" => "海底针"
    },
    %{
      "action" => "$N招「倒骑龙」，左脚一个弓箭步，右手上举向外撇出，向$n的$l挥去",
      "force" => 212,
      "attack" => 39,
      "parry" => 138,
      "dodge" => 115,
      "damage" => 21,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "倒骑龙"
    }
  ]

  @impl true
  def id(), do: "xuangong-quan"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 50}

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

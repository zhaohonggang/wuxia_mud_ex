defmodule Kantele.Combat.Skills.ChongyangShenzhang do
  @moduledoc """
  武学实装「chongyang-shenzhang」（源 chongyang-shenzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/chongyang_shenzhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双掌一错，一招「阳关三叠」幻出层层掌影奔向$n的$l",
      "force" => 70,
      "attack" => 5,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "阳关三叠"
    },
    %{
      "action" => "$N暴喝一声，单掌猛然推出，一招「地久天长」强劲的掌风直扑$n的$l",
      "force" => 90,
      "attack" => 10,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 50,
      "lvl" => 15,
      "damage_type" => "瘀伤",
      "skill_name" => "地久天长"
    },
    %{
      "action" => "$N双掌纷飞，一招「金龙戏水」直取$n的$l",
      "force" => 110,
      "attack" => 20,
      "parry" => 32,
      "dodge" => 32,
      "damage" => 33,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "金龙戏水"
    },
    %{
      "action" => "$N按北斗方位急走，一招「万物复苏」，阵阵掌风无孔不入般地击向$n的$l",
      "force" => 140,
      "attack" => 30,
      "parry" => 45,
      "dodge" => 30,
      "damage" => 70,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "万物复苏"
    },
    %{
      "action" => "$N回身错步，双掌平推，凝神聚气，一招「回光反照」拍向$n的$l",
      "force" => 170,
      "attack" => 35,
      "parry" => 50,
      "dodge" => 45,
      "damage" => 30,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "回光反照"
    },
    %{
      "action" => "$N左掌立于胸前，右掌推出，一招「神光乍现」迅然击向$n$l",
      "force" => 190,
      "attack" => 40,
      "parry" => 52,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "神光乍现"
    },
    %{
      "action" => "$N使出「百里千长」，身形急进，快速向$n出掌攻击",
      "force" => 220,
      "attack" => 40,
      "parry" => 55,
      "dodge" => 65,
      "damage" => 30,
      "lvl" => 110,
      "damage_type" => "瘀伤",
      "skill_name" => "百里千长"
    },
    %{
      "action" => "$N一招「星游九天」，双掌虚虚实实的击向$n的$l",
      "force" => 250,
      "attack" => 45,
      "parry" => 57,
      "dodge" => 60,
      "damage" => 30,
      "lvl" => 130,
      "damage_type" => "瘀伤",
      "skill_name" => "星游九天"
    },
    %{
      "action" => "$N左掌画了个圈圈，右掌推出，一招「北斗易位」击向$n$l",
      "force" => 270,
      "attack" => 50,
      "parry" => 61,
      "dodge" => 68,
      "damage" => 30,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "北斗易位"
    }
  ]

  @impl true
  def id(), do: "chongyang-shenzhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 0}

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

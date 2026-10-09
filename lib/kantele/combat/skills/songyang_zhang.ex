defmodule Kantele.Combat.Skills.SongyangZhang do
  @moduledoc """
  武学实装「songyang-zhang」（源 songyang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/songyang_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「攀阳手」，左手带风，右手拍向$n的$l",
      "force" => 30,
      "attack" => 5,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "攀阳手"
    },
    %{
      "action" => "$N右手微台，直出向前，一式「拂月掌」，疾向$n的$l击去",
      "force" => 45,
      "attack" => 8,
      "parry" => 35,
      "dodge" => 20,
      "damage" => 13,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "拂月掌"
    },
    %{
      "action" => "$N使一式「逆风式」，左掌微拂，右掌顺势而进，猛地插往$n的$l",
      "force" => 60,
      "attack" => 12,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 15,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "逆风式"
    },
    %{
      "action" => "$N双掌隐隐泛出青气，一式「风云手」，掌风激劲，雨点般向$n击去",
      "force" => 76,
      "attack" => 15,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 18,
      "lvl" => 38,
      "damage_type" => "瘀伤",
      "skill_name" => "风云手"
    },
    %{
      "action" => "$N双掌不断反转，使出一式「折手式」，双掌并拢，笔直地向$n的$l袭去",
      "force" => 52,
      "attack" => 18,
      "parry" => 30,
      "dodge" => 33,
      "damage" => 25,
      "lvl" => 55,
      "damage_type" => "瘀伤",
      "skill_name" => "折手式"
    },
    %{
      "action" => "$N身形一变，使一式「齐掌式」，双掌带着萧刹的劲气，猛地击往$n的$l",
      "force" => 90,
      "attack" => 20,
      "parry" => 35,
      "dodge" => 38,
      "damage" => 30,
      "lvl" => 65,
      "damage_type" => "瘀伤",
      "skill_name" => "齐掌式"
    },
    %{
      "action" => "$N使一式「紫烟手」，双掌如梦似幻，同时向$n的$l击去",
      "force" => 120,
      "attack" => 22,
      "parry" => 38,
      "dodge" => 42,
      "damage" => 33,
      "lvl" => 72,
      "damage_type" => "瘀伤",
      "skill_name" => "紫烟手"
    },
    %{
      "action" => "$N一式「流水式」，身法忽变，似流云飘忽，不觉已击到$n的$l上",
      "force" => 140,
      "attack" => 24,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 38,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "流水式"
    },
    %{
      "action" => "$N突地一招「天雷手」，双掌挟着一阵风雷之势，猛地劈往$n的$l",
      "force" => 160,
      "attack" => 26,
      "parry" => 50,
      "dodge" => 50,
      "damage" => 50,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "天雷手"
    }
  ]

  @impl true
  def id(), do: "songyang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 45}

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

defmodule Kantele.Combat.Skills.JueqingZhang do
  @moduledoc """
  武学实装「jueqing-zhang」（源 jueqing-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jueqing_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「情非得以」，右掌一翻，向$n的$l拍去",
      "force" => 90,
      "attack" => 4,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "情非得以"
    },
    %{
      "action" => "$N使一招「落花有意」，左手猛地拍向$n的$l",
      "force" => 110,
      "attack" => 6,
      "parry" => 30,
      "dodge" => 48,
      "damage" => 40,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "落花有意"
    },
    %{
      "action" => "$N双目微闭，一式「不堪回首」，掌力浑厚，击向$n的$l",
      "force" => 120,
      "attack" => 10,
      "parry" => 60,
      "dodge" => 50,
      "damage" => 48,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "不堪回首"
    },
    %{
      "action" => "$N双手微抬，左右齐出，一招「回头太难」，已将$n$l笼罩",
      "force" => 150,
      "attack" => 12,
      "parry" => 71,
      "dodge" => 44,
      "damage" => 55,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "回头太难"
    },
    %{
      "action" => "$N双掌翻腾，却欲停止，一式「覆水难收」，飘然不定，击向$n$l",
      "force" => 180,
      "attack" => 15,
      "parry" => 60,
      "dodge" => 55,
      "damage" => 60,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "覆水难收"
    },
    %{
      "action" => "$N单掌直出，内劲十足，一式「绝情绝义」，掌法一快一慢，向$n的$l打去",
      "force" => 210,
      "attack" => 15,
      "parry" => 62,
      "dodge" => 60,
      "damage" => 70,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "绝情绝义"
    },
    %{
      "action" => "$N快步踏出，双掌暗自运劲，一招「恩断情绝」，掌风已到$n$l",
      "force" => 240,
      "attack" => 18,
      "parry" => 71,
      "dodge" => 80,
      "damage" => 80,
      "lvl" => 110,
      "damage_type" => "瘀伤",
      "skill_name" => "恩断情绝"
    },
    %{
      "action" => "$N左掌忽地拍向$n，又突然收回，紧跟着右掌斜出，一招「",
      "force" => 280,
      "attack" => 25,
      "parry" => 80,
      "dodge" => 76,
      "damage" => 90,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "流水无情"
    }
  ]

  @impl true
  def id(), do: "jueqing-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 60}

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

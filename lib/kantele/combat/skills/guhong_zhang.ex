defmodule Kantele.Combat.Skills.GuhongZhang do
  @moduledoc """
  武学实装「guhong-zhang」（源 guhong-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/guhong_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「奔流直下」，右掌一翻，向$n的$l拍去",
      "force" => 55,
      "attack" => 4,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "奔流直下"
    },
    %{
      "action" => "$N使一招「力挡群山」，右手斜出，劈向$n的$l",
      "force" => 68,
      "attack" => 6,
      "parry" => 30,
      "dodge" => 48,
      "damage" => 30,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "力挡群山"
    },
    %{
      "action" => "$N双手带风，一式「单刀附会」，掌力浑厚，击向$n的$l",
      "force" => 78,
      "attack" => 10,
      "parry" => 60,
      "dodge" => 50,
      "damage" => 38,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "单刀附会"
    },
    %{
      "action" => "$N双手微抬，左右齐出，一招「水中探月」，已将$n$l笼罩",
      "force" => 86,
      "attack" => 12,
      "parry" => 71,
      "dodge" => 44,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "水中探月"
    },
    %{
      "action" => "$N双掌翻腾，掌风凌厉，一式「春风细雨」，飘然不定，击向$n$l",
      "force" => 100,
      "attack" => 15,
      "parry" => 60,
      "dodge" => 55,
      "damage" => 50,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "春风细雨"
    },
    %{
      "action" => "$N双掌拍出，一式「双管齐下」，掌法一快一慢，向$n的$l打去",
      "force" => 125,
      "attack" => 15,
      "parry" => 55,
      "dodge" => 60,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "双管齐下"
    },
    %{
      "action" => "$N快步向前，身法陡快，一招「秋卷落叶」，掌风已到$n$l",
      "force" => 140,
      "attack" => 18,
      "parry" => 71,
      "dodge" => 80,
      "damage" => 63,
      "lvl" => 110,
      "damage_type" => "瘀伤",
      "skill_name" => "秋卷落叶"
    },
    %{
      "action" => "$N双掌下垂，似是无力，但又猛然加快，似攻非攻，一式「人海孤鸿」\\n",
      "force" => 155,
      "attack" => 25,
      "parry" => 80,
      "dodge" => 76,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "人海孤鸿"
    }
  ]

  @impl true
  def id(), do: "guhong-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 40}

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


  @impl true
  def perform_list() do
    %{
      "qian" => Kantele.Combat.Skills.Performs.GuhongZhang.Qian
    }
  end
end

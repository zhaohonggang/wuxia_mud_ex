defmodule Kantele.Combat.Skills.LiuheZhang do
  @moduledoc """
  武学实装「liuhe-zhang」（源 liuhe-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/liuhe_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「正掌还经」，单掌平势缓推而出，陡然拍向$n的$l",
      "force" => 33,
      "attack" => 2,
      "parry" => 2,
      "dodge" => 5,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "正掌还经"
    },
    %{
      "action" => "$N使一招「合掌擎天」，右手划了一个圈子，左手挥出，劈向$n的$l",
      "force" => 45,
      "attack" => 6,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 4,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "合掌擎天"
    },
    %{
      "action" => "$N右手由钩变掌，使一招「切掌现影」，单掌登时横扫$n的$l",
      "force" => 51,
      "attack" => 11,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 7,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "切掌现影"
    },
    %{
      "action" => "$N双手划弧，右手向上，左手向下，使一招「翻掌劈山」砍向$n的面门",
      "force" => 62,
      "attack" => 15,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 9,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "翻掌劈山"
    },
    %{
      "action" => "$N左手划了一个大圈，使一招「穿掌行柳」，击向$n的$l",
      "force" => 75,
      "attack" => 19,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 11,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "穿掌行柳"
    },
    %{
      "action" => "$N双手合掌，使一招「引掌开峰」，双掌分别向$n的$l打去",
      "force" => 90,
      "attack" => 21,
      "parry" => 30,
      "dodge" => 28,
      "damage" => 14,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "引掌开峰"
    }
  ]

  @impl true
  def id(), do: "liuhe-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 48, neili: 42}

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
      "tan" => Kantele.Combat.Skills.Performs.LiuheZhang.Tan
    }
  end
end

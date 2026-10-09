defmodule Kantele.Combat.Skills.TongchuiZhang do
  @moduledoc """
  武学实装「tongchui-zhang」（源 tongchui-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tongchui_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「千锤百炼」，单掌平势缓推而出，陡然拍向$n的$l",
      "force" => 33,
      "attack" => 2,
      "parry" => 2,
      "dodge" => 5,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "千锤百炼"
    },
    %{
      "action" => "$N使一招「旁敲侧击」，右手划了一个圈子，左手挥劈$n而去",
      "force" => 45,
      "attack" => 6,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 4,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "旁敲侧击"
    },
    %{
      "action" => "$N右手由钩变掌，使一招「力拔千钧」，单掌登时横扫$n的$l",
      "force" => 51,
      "attack" => 11,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 7,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "力拔千钧"
    },
    %{
      "action" => "$N双手划弧，双掌轮番拍出，使一招「威震八方」砍向$n的面门",
      "force" => 62,
      "attack" => 15,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 9,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "威震八方"
    }
  ]

  @impl true
  def id(), do: "tongchui-zhang"

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

end

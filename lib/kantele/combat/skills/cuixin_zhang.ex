defmodule Kantele.Combat.Skills.CuixinZhang do
  @moduledoc """
  武学实装「cuixin-zhang」（源 cuixin-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/cuixin_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「百花凋零」，运掌如飞，招招直打$n的$l",
      "force" => 220,
      "attack" => 25,
      "parry" => 16,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "百花凋零"
    },
    %{
      "action" => "$N使出一招「万木皆枯」，双掌急运内力，带着凛冽的掌风直拍$n的$l",
      "force" => 280,
      "attack" => 55,
      "parry" => 19,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "万木皆枯"
    },
    %{
      "action" => "$N飞身一跃而起，一声怪叫，一招「魂飞魄散」，双掌铺天盖地般拍向$n",
      "force" => 340,
      "attack" => 67,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "魂飞魄散"
    },
    %{
      "action" => "$N惨然一声长啸，一招「收魂摄魄」，双掌猛然击下，直扑$n的要脉",
      "force" => 440,
      "attack" => 85,
      "parry" => 38,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "收魂摄魄"
    },
    %{
      "action" => "$N大叫一声，骨骼一阵暴响，双臂忽然暴长数尺，一招「六阴追魂」直直攻向$n的$l",
      "force" => 470,
      "attack" => 90,
      "parry" => 43,
      "dodge" => 40,
      "damage" => 65,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "六阴追魂"
    },
    %{
      "action" => "$N一招「裂骨催心」，双掌缤纷拍出，化出满天掌影，陡然间一掌已迅捷无比的拍向$n",
      "force" => 480,
      "attack" => 126,
      "parry" => 55,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "裂骨催心"
    }
  ]

  @impl true
  def id(), do: "cuixin-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 120}

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
      "cui" => Kantele.Combat.Skills.Performs.CuixinZhang.Cui
    }
  end
end

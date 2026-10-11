defmodule Kantele.Combat.Skills.SanyinWugongzhao do
  @moduledoc """
  武学实装「sanyin-wugongzhao」（源 sanyin-wugongzhao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/sanyin_wugongzhao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N爪现青白，骨结隆起，自上而下撕扯$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双手忽隐忽现，爪爪鬼魅般抓向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 30,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N身形围$n一转，爪影纵横毫不留情对着$n的$l抓下",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 60,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N一声怪叫，一爪横出直击$n的$l",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 60,
      "lvl" => 90,
      "damage_type" => "抓伤",
      "skill_name" => "唯我独尊"
    },
    %{
      "action" => "$N两眼邪光闪动，身子飘飘忽忽，抽身探出一爪猛然击向$n的$l",
      "force" => 270,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 90,
      "lvl" => 120,
      "damage_type" => "抓伤",
      "skill_name" => "唯我独尊"
    }
  ]

  @impl true
  def id(), do: "sanyin-wugongzhao"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 31}

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
      "zhua" => Kantele.Combat.Skills.Performs.SanyinWugongzhao.Zhua
    }
  end
end

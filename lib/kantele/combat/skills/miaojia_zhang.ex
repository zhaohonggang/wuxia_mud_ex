defmodule Kantele.Combat.Skills.MiaojiaZhang do
  @moduledoc """
  武学实装「miaojia-zhang」（源 miaojia-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/miaojia_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N划身错步，双掌内拢外托，缓缓向$n的左肩处拍去",
      "force" => 70,
      "attack" => 5,
      "parry" => 38,
      "dodge" => 38,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "逆流捧沙"
    },
    %{
      "action" => "$N跨前一步，双掌以迅雷不及掩耳之势，劈向$n两额太阳穴",
      "force" => 95,
      "attack" => 8,
      "parry" => 43,
      "dodge" => 43,
      "damage" => 4,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "雷洞霹雳"
    },
    %{
      "action" => "$N单掌突起，劲气弥漫，双掌如轮，一环环向$n的后背斫去",
      "force" => 120,
      "attack" => 13,
      "parry" => 51,
      "dodge" => 51,
      "damage" => 8,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "摘星换斗"
    },
    %{
      "action" => "$N双掌似让非让，似顶非顶，气浪如急流般使$n陷身其中",
      "force" => 140,
      "attack" => 15,
      "parry" => 65,
      "dodge" => 65,
      "damage" => 12,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "梵心降魔"
    }
  ]

  @impl true
  def id(), do: "miaojia-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 20, neili: 40}

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
      "dan" => Kantele.Combat.Skills.Performs.MiaojiaZhang.Dan
    }
  end
end

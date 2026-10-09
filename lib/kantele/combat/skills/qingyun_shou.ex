defmodule Kantele.Combat.Skills.QingyunShou do
  @moduledoc """
  武学实装「qingyun-shou」（源 qingyun-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qingyun_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N跨前一步，一式「寒月初升」，单手一拂而过，拍向$n的$l",
      "force" => 70,
      "attack" => 5,
      "parry" => 38,
      "dodge" => 38,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "寒月初升"
    },
    %{
      "action" => "$N一式「云雾茫茫」，双手缤纷拍出，同时击向$n的胸前几大要穴",
      "force" => 95,
      "attack" => 8,
      "parry" => 43,
      "dodge" => 43,
      "damage" => 4,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "云雾茫茫"
    },
    %{
      "action" => "$N使一式「天际排云」，双掌纷飞，连续拍出，掌影向$n层层推进",
      "force" => 120,
      "attack" => 13,
      "parry" => 51,
      "dodge" => 51,
      "damage" => 8,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "天际排云"
    },
    %{
      "action" => "$N一式「平步青云」，单手一挥，手影虚虚实实，难辨真伪，完全笼罩$n",
      "force" => 140,
      "attack" => 15,
      "parry" => 65,
      "dodge" => 65,
      "damage" => 12,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "平步青云"
    }
  ]

  @impl true
  def id(), do: "qingyun-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

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

end

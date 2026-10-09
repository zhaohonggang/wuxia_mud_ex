defmodule Kantele.Combat.Skills.ShaozeSword do
  @moduledoc """
  武学实装「shaoze-sword」（源 shaoze-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shaoze_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手小指一伸，一条气流从少冲穴中激射而出，“少泽剑”",
      "force" => 320,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少泽剑"
    }
  ]

  @impl true
  def id(), do: "shaoze-sword"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 80}

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

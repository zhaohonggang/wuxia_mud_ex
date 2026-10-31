defmodule Kantele.Combat.Skills.Gun do
  @moduledoc """
  武学实装「gun」（源 gun.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/gun/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "",
      "force" => 999,
      "attack" => 999,
      "parry" => 999,
      "dodge" => 999,
      "damage" => 999,
      "lvl" => 0,
      "damage_type" => "枪伤"
    }
  ]

  @impl true
  def id(), do: "gun"

  @impl true
  def valid_enable(usage), do: usage in ["hammer"]

  @impl true
  def practice_cost(), do: %{qi: 1, neili: 0}

  # LPC `valid_learn(object me)`（源 gun.c）
  @impl true
  def valid_learn(_stats, character) do
    cond do
      not (wizard?(character)) ->
        {:error, "你无法学习枪械技术。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "she" => Kantele.Combat.Skills.Performs.Gun.She
    }
  end

  # LPC `wizardp(me)`：本端口巫师判定在 `Kantele.Admin.Access.wizardp/1`
  # （读 `attributes["wiz_level"]`）。`valid_learn/2` 收到的是角色快照，
  # 非完整 `Kalevala.Character`，该函数对非角色入参恒 false（= LPC 非巫师玩家）。
  defp wizard?(character), do: Kantele.Admin.Access.wizardp(character)
end

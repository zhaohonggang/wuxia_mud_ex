defmodule Kantele.Combat.Skills.Longxiang do
  @moduledoc """
  武学实装「longxiang」（源 longxiang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, practice_skill, skill_improved, valid_force
  - perform/exert 路由骨架见 tmp/perf_out/longxiang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "longxiang"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  # LPC `valid_learn(object me)`（源 longxiang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    gender = gender_of(character)

    cond do
      Stats.skill(stats, "force") < 70 ->
        {:error, "你的基本内功火候还不够。\n"}

      (gender == "无性") and (lvl > 49) ->
        {:error, "你无根无性，阴阳不调，难以领会高深的龙象般若功。\n"}

      Stats.str(stats) < 30 ->
        {:error, "你先天膂力不足，无法学习刚猛的龙象般若功。\n"}

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
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.Longxiang.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.Longxiang.Shield
    }
  end

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"
end

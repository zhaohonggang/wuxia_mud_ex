defmodule Kantele.Combat.Skills.YiweiDujiang do
  @moduledoc """
  武学实装「yiwei-dujiang」（源 yiwei-dujiang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yiwei_dujiang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "yiwei-dujiang"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 0}

  # LPC `valid_learn(object me)`（源 yiwei-dujiang.c）
  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.dex(stats) < 24 ->
        {:error, "你先天身法不足！\n"}

      Stats.int(stats) < 26 ->
        {:error, "你先天悟性不足！\n"}

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
      "dujiang" => Kantele.Combat.Skills.Performs.YiweiDujiang.Dujiang
    }
  end
end

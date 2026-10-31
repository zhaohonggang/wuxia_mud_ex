defmodule Kantele.Combat.Skills.YufengZhen do
  @moduledoc """
  武学实装「yufeng-zhen」（源 yufeng-zhen.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yufeng_zhen/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "yufeng-zhen"

  @impl true
  def valid_enable(usage), do: usage in ["throwing"]

  # LPC valid_learn：force>=60 / dodge>=80 / query_dex()>=26 / throwing>=yufeng-zhen
  @impl true
  def valid_learn(stats, _character) do
    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功心法火候不够，无法学玉蜂针。\n"}

      Stats.skill(stats, "dodge") < 80 ->
        {:error, "你的轻功火候不够，无法领悟玉蜂针。\n"}

      # LPC me->query_dex() 是派生身法（base+tattoo+reborn+dodge/10）
      Stats.query_dex(stats) < 26 ->
        {:error, "你的身法不够灵巧，无法领悟玉蜂针。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，难以领会更高深的玉蜂针。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 52, neili: 35}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "ying" => Kantele.Combat.Skills.Performs.YufengZhen.Ying
    }
  end
end

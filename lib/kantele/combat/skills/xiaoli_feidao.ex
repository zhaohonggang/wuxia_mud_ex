defmodule Kantele.Combat.Skills.XiaoliFeidao do
  @moduledoc """
  武学实装「xiaoli-feidao」（源 xiaoli-feidao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiaoli_feidao/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "xiaoli-feidao"

  @impl true
  def valid_enable(usage), do: usage in ["throwing"]

  # LPC valid_learn：max_neili>=1500 / force>=200 / throwing>=xiaoli-feidao
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1500 ->
        {:error, "你的内力不够，没有办法练小李飞刀。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，没有办法练小李飞刀。\n"}

      Stats.skill(stats, "throwing") < Stats.skill(stats, id()) ->
        {:error, "你的基本暗器水平有限，无法领会更高深的小李飞刀。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 48}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "fei" => Kantele.Combat.Skills.Performs.XiaoliFeidao.Fei
    }
  end
end

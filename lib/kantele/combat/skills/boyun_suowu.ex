defmodule Kantele.Combat.Skills.BoyunSuowu do
  @moduledoc """
  拨云锁雾（对照 `kungfu/skill/boyun-suowu.c`）

  拳脚载体：`valid_enable("hand")`、`valid_enable("dodge")`、`valid_enable("parry")`；
  仅可学不可练。`valid_force` 接受 碧云心法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/boyun_suowu/`。

  学习门槛 `valid_learn/2`（biyun-xinfa>=10 / max_neili>=100）与
  练招消耗 `practice_cost`（LPC 扣 qi 25 / neili 100，空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「空手（query_temp("weapon")）」检查未在 `valid_learn` 建模
  （学习/练习本就空手，由 practice 流程把关），招式表沿用基类占位 TODO。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "boyun-suowu"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "dodge", "parry"]

  @impl true
  def valid_force(force), do: force == "biyun-xinfa"

  # LPC valid_learn 要求 biyun-xinfa>=10 / max_neili>=100（空手检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "biyun-xinfa") < 10 ->
        {:error, "你的碧云心法火候不够，无法学拨云锁雾。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练拨云锁雾。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 25 / neili 100（空手）"
  @impl true
  def practice_cost(), do: %{qi: 25, neili: 100}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "dian" => Kantele.Combat.Skills.Performs.BoyunSuowu.Dian,
      "meng" => Kantele.Combat.Skills.Performs.BoyunSuowu.Meng
    }
  end
end

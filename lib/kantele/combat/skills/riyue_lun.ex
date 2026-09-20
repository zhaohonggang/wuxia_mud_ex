defmodule Kantele.Combat.Skills.RiyueLun do
  @moduledoc """
  日月轮法（对照 `kungfu/skill/riyue-lun.c`）

  轮/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/riyue_lun/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=1000 门槛本版以 force>=150 代理
    （引擎 `valid_learn/1` 只拿 stats，无 vitals）；
  - LPC 招式表与 `practice_skill` 未建模（`query_action` 返回空、
    `practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "riyue-lun"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      stats.str < 32 ->
        {:error, "你先天膂力不足，难以修炼日月轮法。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"yuan" => Kantele.Combat.Skills.Performs.RiyueLun.Yuan}
  end
end
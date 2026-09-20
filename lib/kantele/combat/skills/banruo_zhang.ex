defmodule Kantele.Combat.Skills.BanruoZhang do
  @moduledoc """
  般若掌（对照 `kungfu/skill/banruo-zhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/banruo_zhang/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=100 门槛本版以 force>=30 代理（引擎
    `valid_learn/1` 只拿 stats，无 vitals），「必须空手」判断未建模；
  - LPC 招式表与 `practice_skill` 未建模（`query_action` 返回空、
    `practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "banruo-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，无法练般若掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法火候水平有限，无法领会更高深的般若功。\n"}

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
    %{"feng" => Kantele.Combat.Skills.Performs.BanruoZhang.Feng}
  end
end
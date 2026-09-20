defmodule Kantele.Combat.Skills.CibeiDao do
  @moduledoc """
  慈悲刀法（对照 `kungfu/skill/cibei-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/cibei_dao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=100 门槛本版以 force>=30 代理（引擎
    `valid_learn/1` 只拿 stats，无 vitals）；
  - LPC 招式表与 `practice_skill`（须持刀 qi60/neili60）未建模
    （`query_action` 返回空、`practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "cibei-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的慈悲刀法。\n"}

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
    %{"sheshen" => Kantele.Combat.Skills.Performs.CibeiDao.Sheshen}
  end
end
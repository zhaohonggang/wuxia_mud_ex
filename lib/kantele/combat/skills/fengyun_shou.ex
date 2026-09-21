defmodule Kantele.Combat.Skills.FengyunShou do
  @moduledoc """
  风云手（对照 `kungfu/skill/fengyun-shou.c`）

  手法载体：`valid_enable("hand")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fengyun_shou/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、max_neili>=200，本版以 force>=40 代理；
  - LPC `valid_combine("yingzhua-gong")` 合璧用法未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fengyun-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候不够，无法学风云手。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"qinna" => Kantele.Combat.Skills.Performs.FengyunShou.Qinna}
  end
end
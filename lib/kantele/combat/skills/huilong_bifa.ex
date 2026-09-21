defmodule Kantele.Combat.Skills.HuilongBifa do
  @moduledoc """
  回龙璧法（对照 `kungfu/skill/huilong-bifa.c`）

  暗器载体：`valid_enable("throwing")`。

  绝招实现见 `lib/kantele/combat/skills/performs/huilong_bifa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 throwing>=100，本版保留该门槛；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huilong-bifa"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "throwing") < 100 ->
        {:error, "你的暗器功夫不够娴熟。\n"}

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
    %{"cang" => Kantele.Combat.Skills.Performs.HuilongBifa.Cang}
  end
end
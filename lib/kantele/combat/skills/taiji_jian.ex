defmodule Kantele.Combat.Skills.TaijiJian do
  @moduledoc """
  太极剑法（对照 `kungfu/skill/taiji-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/taiji_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=1500 门槛本版以 force>=200 代理
    （引擎 `valid_learn/1` 只拿 stats，无 vitals）；
  - LPC 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "taiji-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 26 ->
        {:error, "你先天悟性太差，难以领会太极剑的要诣。\n"}

      Stats.skill(stats, "force") < 200 ->
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
    %{
      "sui" => Kantele.Combat.Skills.Performs.TaijiJian.Sui,
      "chan" => Kantele.Combat.Skills.Performs.TaijiJian.Chan,
      "zhuan" => Kantele.Combat.Skills.Performs.TaijiJian.Zhuan
    }
  end
end
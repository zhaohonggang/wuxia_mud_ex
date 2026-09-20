defmodule Kantele.Combat.Skills.DamoJian do
  @moduledoc """
  达摩剑（对照 `kungfu/skill/damo-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/damo_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=300 门槛本版以 force>=60 代理（引擎
    `valid_learn/1` 只拿 stats，无 vitals）；
  - LPC 招式表与 `practice_skill`（须持剑 qi70/neili70）未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "damo-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 30 ->
        {:error, "你的先天悟性不足。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的达摩剑法。\n"}

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
    %{"qingxin" => Kantele.Combat.Skills.Performs.DamoJian.Qingxin}
  end
end
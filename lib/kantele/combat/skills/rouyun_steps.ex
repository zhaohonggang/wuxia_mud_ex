defmodule Kantele.Combat.Skills.RouyunSteps do
  @moduledoc """
  柔云步（对照 `kungfu/skill/rouyun-steps.c`）

  轻功载体：`valid_enable("dodge")`、`valid_enable("move")`。

  差异（TODO(migrate)）：
  - LPC `query_action` 返回移动动作，本模型未实现。
  - `zong`（柔云纵）为随机传送技能，目标为随机房间。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "rouyun-steps"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def valid_learn(stats, _character) do
    if Stats.dex(stats) <= 30 do
      {:error, "你的身法不够，难以领会柔云步法。"}
    else
      :ok
    end
  end

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 20"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 20}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zong" => Kantele.Combat.Skills.Performs.RouyunSteps.Zong}
  end
end

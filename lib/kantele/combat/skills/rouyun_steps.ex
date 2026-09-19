defmodule Kantele.Combat.Skills.RouyunSteps do
  @moduledoc """
  柔云步（对照 `kungfu/skill/rouyun-steps.c`）

  轻功载体：`valid_enable("dodge")`、`valid_enable("move")`。

  差异（TODO(migrate)）：
  - LPC `query_action` 返回移动动作，本模型未实现。
  - `zong`（柔云纵）为随机传送技能，目标为随机房间。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "rouyun-steps"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zong" => Kantele.Combat.Skills.Performs.RouyunSteps.Zong}
  end
end
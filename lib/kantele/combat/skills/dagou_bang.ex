defmodule Kantele.Combat.Skills.DagouBang do
  @moduledoc """
  打狗棒法（对照 `kungfu/skill/dagou-bang.c`）

  杖法载体：`valid_enable("staff")`、`valid_enable("parry")`；
  `valid_force` 接受 蛤蟆功/混元一气/九阴真经 共存。

  差异（TODO(migrate)）：LPC `valid_learn` 的性别/性格限制未实现。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "dagou-bang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_force(force), do: force in ["hamagong", "hunyuan-yiqi", "jiuyin-zhenjing"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.DagouBang.Chan,
      "feng" => Kantele.Combat.Skills.Performs.DagouBang.Feng,
      "tian" => Kantele.Combat.Skills.Performs.DagouBang.Tian
    }
  end
end

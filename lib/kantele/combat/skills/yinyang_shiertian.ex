defmodule Kantele.Combat.Skills.YinyangShiertian do
  @moduledoc """
  武学实装「yinyang-shiertian」（阴阳十二重天）
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "yinyang-shiertian"

  @impl true
  def valid_enable(_usage), do: false

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.YinyangShiertian.Powerup
    }
  end
end

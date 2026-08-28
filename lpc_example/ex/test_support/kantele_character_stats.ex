defmodule Kantele.Character.Stats do
  @moduledoc """
  Faithful test double of the real `lib/kantele/character.ex` `Kantele.Character.Stats`.

  The real module lives inside an Ecto-heavy file (`character.ex`) that cannot be
  compiled standalone for isolated `elixirc` smoke tests. This copy mirrors the
  real struct fields and `skill/2` API verbatim, so tests compiled against this
  double are API-identical to the real framework. Keep in sync with
  `lib/kantele/character.ex` (the real Stats) when it changes.
  """

  defstruct [
    :str,
    :dex,
    :con,
    :int,
    :combat_exp,
    :potential,
    :learned_points,
    :skills,
    :mapped,
    :performs,
    :score,
    :weiwang,
    :gongxian,
    :shen
  ]

  def new() do
    %__MODULE__{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 1000,
      potential: 100,
      learned_points: 0,
      score: 0,
      weiwang: 0,
      gongxian: 0,
      shen: 0,
      skills: %{"unarmed" => 60, "sword" => 60, "dodge" => 60, "parry" => 60, "force" => 20},
      mapped: %{},
      performs: MapSet.new()
    }
  end

  @doc "查询技能等级，未习得为 0（与真实实现一致）"
  def skill(%__MODULE__{} = stats, name), do: Map.get(stats.skills, name, 0)

  @doc "可用潜能 = 总潜能 - 已消耗"
  def available_potential(%__MODULE__{} = stats),
    do: max((stats.potential || 0) - (stats.learned_points || 0), 0)
end

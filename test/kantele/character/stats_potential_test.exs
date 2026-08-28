defmodule Kantele.Character.StatsPotentialTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats

  test "potential 返回可用潜能（总潜力 - 已学点数）" do
    stats = Stats.new()

    assert Stats.potential(stats) == Stats.available_potential(stats)
    assert Stats.potential(stats) == 100
  end

  test "add_potential 发放潜能（正数记入总潜力）" do
    stats = Stats.new() |> Stats.add_potential(50)

    assert stats.potential == 150
    assert Stats.potential(stats) == 150
  end

  test "add_potential 消耗潜能（负数记入已学点数）" do
    stats = Stats.new() |> Stats.add_potential(-30)

    assert stats.learned_points == 30
    assert Stats.potential(stats) == 70

    # 消耗到 0 为止，可用潜能不能为负
    drained = Stats.new() |> Stats.add_potential(-999)
    assert Stats.potential(drained) == 0
  end

  test "potential_limit 以已学点数为基准" do
    stats = Stats.new()
    assert Stats.potential_limit(stats) == 100

    stats = Stats.spend_potential(stats, 10)
    assert Stats.potential_limit(stats) == 110
  end

  test "improve_potential 发放但不越可用上限" do
    # 初始 available=100, limit=100，无可发放空间
    at_limit = Stats.new() |> Stats.improve_potential(20)
    assert Stats.potential(at_limit) == 100

    # 消耗后腾出空间，可补回一部分
    spent = Stats.new() |> Stats.add_potential(-40) |> Stats.improve_potential(20)
    assert Stats.potential(spent) == 80
  end
end

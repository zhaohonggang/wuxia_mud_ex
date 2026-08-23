defmodule Kantele.Character.VitalsTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  test "damage 扣气血且不为负" do
    vitals = Vitals.new()
    vitals = Vitals.damage(vitals, :qi, 50)

    assert vitals.qi == vitals.max_qi - 50

    vitals = Vitals.damage(vitals, :qi, 999_999)
    assert vitals.qi == 0
  end

  test "wound 削减上限并夹住当前值（receive_wound）" do
    vitals = Vitals.new()
    wounded = Vitals.wound(vitals, :qi, 30)

    assert wounded.max_qi == vitals.max_qi - 30
    assert wounded.qi == vitals.max_qi - 30

    # 上限不会被打穿
    assert Vitals.wound(vitals, :qi, 100_000).max_qi == 1
  end

  test "regenerate 自然回复，战斗中放缓" do
    stats = %Stats{Stats.new() | con: 20, skills: %{"force" => 60}}
    vitals = Vitals.damage(Vitals.new(), :qi, 100)

    idle = Vitals.regenerate(vitals, stats, false)
    fighting = Vitals.regenerate(vitals, stats, true)

    # 非战斗回复量 = (con*2+10)/1 = 50；战斗中为 /4 = 12
    assert idle.qi == 100
    assert fighting.qi == 62

    # 不超过上限；内力按 force/3 加成
    full = Vitals.regenerate(Vitals.new(), stats, false)
    assert full.qi == full.max_qi
    assert full.neili == full.max_neili
  end
end

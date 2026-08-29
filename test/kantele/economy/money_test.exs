defmodule Kantele.Economy.MoneyTest do
  use ExUnit.Case, async: true

  alias Kantele.Economy.Money

  test "denominations" do
    assert Money.denominations() == %{"gold" => 10_000, "silver" => 100, "coin" => 1}
  end

  test "split: 拆成面额枚数" do
    assert Money.split(0) == %{"gold" => 0, "silver" => 0, "coin" => 0}
    assert Money.split(150_000) == %{"gold" => 15, "silver" => 0, "coin" => 0}
    assert Money.split(15_250) == %{"gold" => 1, "silver" => 52, "coin" => 50}
    assert Money.split(99) == %{"gold" => 0, "silver" => 0, "coin" => 99}
  end

  test "total_value" do
    assert Money.total_value(%{"gold" => 1, "silver" => 2, "coin" => 3}) == 10_203
    assert Money.total_value(%{}) == 0
  end

  test "can_afford: 0 不够 / 1 足够 / 2 找不开" do
    # 只有 coin，总额 50，买 60 -> 0
    assert Money.can_afford(%{"coin" => 50}, 60) == 0
    # coin 足够 -> 1
    assert Money.can_afford(%{"coin" => 60}, 60) == 1
    # 有 silver 但 amount 不是 100 整倍数 -> 2
    assert Money.can_afford(%{"silver" => 1}, 60) == 2
    # silver 整倍数 -> 1
    assert Money.can_afford(%{"silver" => 2}, 100) == 1
    # 有 gold，amount 是 10000 整倍数 -> 1
    assert Money.can_afford(%{"gold" => 2}, 10_000) == 1
    # gold 但 amount 不是 10000 整倍数且无 silver -> 2
    assert Money.can_afford(%{"gold" => 2}, 15_000) == 2
  end

  test "pay: 从各面额扣除并找零" do
    # 用 gold 付 15000 -> gold-2, silver+50
    assert Money.pay(%{"gold" => 2, "silver" => 0, "coin" => 0}, 15_000) ==
             {:ok, %{"gold" => 0, "silver" => 50, "coin" => 0}}

    # 用 silver+coin 付 250 -> silver-2, coin+50
    assert Money.pay(%{"gold" => 0, "silver" => 3, "coin" => 0}, 250) ==
             {:ok, %{"gold" => 0, "silver" => 0, "coin" => 50}}

    # 不够 -> :error
    assert Money.pay(%{"coin" => 10}, 11) == :error
  end

  test "money_str 显示" do
    assert Money.money_str(0) == "一文钱"
    assert Money.money_str(15_000) == "一两黄金又五十两白银"
    assert Money.money_str(250) == "二两白银又五十文铜钱"
    assert Money.money_str(5) == "五文铜钱"
  end
end

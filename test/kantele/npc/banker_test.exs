defmodule Kantele.Npc.BankerTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.Banker

  defp pouch, do: %{"gold" => 2, "silver" => 10, "coin" => 100}

  test "check: 无余额 / 有余额" do
    assert Banker.check(nil) == {:empty}
    assert Banker.check(0) == {:empty}
    assert Banker.check(15_000) == {:balance, 15_000}
  end

  test "convert: 铜换银" do
    # 100 coin -> 1 silver
    assert Banker.convert(%{"coin" => 100}, 100, "coin", "silver") ==
             {:ok, %{"coin" => 0, "silver" => 1, "gold" => 0}}

    # coin 不足
    assert match?({:error, _}, Banker.convert(%{"coin" => 50}, 100, "coin", "silver"))
  end

  test "convert: 银换金" do
    # 10000 silver -> 100 gold
    assert Banker.convert(%{"silver" => 10_000}, 10_000, "silver", "gold") ==
             {:ok, %{"silver" => 0, "gold" => 100, "coin" => 0}}
  end

  test "convert: 校验" do
    assert match?({:error, _}, Banker.convert(pouch(), 1, "gold", "gold"))
    assert match?({:error, _}, Banker.convert(pouch(), 0, "coin", "silver"))
    assert match?({:error, _}, Banker.convert(pouch(), 5, "gold", "nonexist"))
  end

  # R11：命令层文案必须先问这里拿成交枚数，不能自己按总价值再算一遍。
  describe "convert_quote/3（成交枚数的单一来源）" do
    test "小面额换大面额：向下取整到整份" do
      assert Banker.convert_quote(100, "coin", "silver") == {100, 1}
      assert Banker.convert_quote(250, "coin", "silver") == {200, 2}
      assert Banker.convert_quote(99, "coin", "silver") == {0, 0}
    end

    test "大面额换小面额：按比例放大" do
      assert Banker.convert_quote(5, "silver", "coin") == {5, 500}
      assert Banker.convert_quote(1, "gold", "coin") == {1, 10_000}
      assert Banker.convert_quote(2, "gold", "silver") == {2, 200}
      assert Banker.convert_quote(10, "silver", "gold") == {0, 0}
    end

    test "与 convert/4 的实际成交一致（quote 是唯一的取整实现）" do
      # 都喂同一份可直接对比的 money_map：coin 100 换 silver
      {:ok, new_map} = Banker.convert(%{"coin" => 100, "silver" => 0, "gold" => 0}, 100, "coin", "silver")

      {from_amount, to_amount} = Banker.convert_quote(100, "coin", "silver")

      assert new_map["coin"] == 100 - from_amount
      assert new_map["silver"] == to_amount
    end
  end

  test "deposit: 存钱累加 balance，扣面额" do
    assert Banker.deposit(pouch(), 0, 2, "gold") ==
             {:ok, 20_000, %{"gold" => 0, "silver" => 10, "coin" => 100}}

    assert match?({:error, _}, Banker.deposit(pouch(), 0, 999, "coin"))
  end

  test "withdraw: 取钱减 balance，加面额" do
    assert Banker.withdraw(%{"gold" => 1, "silver" => 0, "coin" => 0}, 20_000, 1, "gold") ==
             {:ok, 10_000, %{"gold" => 2, "silver" => 0, "coin" => 0}}
  end

  test "withdraw: 超限 / 不够 / 非法单位" do
    assert match?({:error, _}, Banker.withdraw(pouch(), 0, 1, "gold"))
    assert match?({:error, _}, Banker.withdraw(%{"coin" => 0}, 100_000, 10_000, "gold"))
    assert match?({:error, _}, Banker.withdraw(pouch(), 100_000, 1, "diamond"))
  end

  test "transfer: 转账扣钱" do
    assert Banker.transfer(20_000, 1, "gold") == {:ok, 10_000, 10_000}
    assert match?({:error, _}, Banker.transfer(0, 1, "gold"))
    assert match?({:error, _}, Banker.transfer(100_000, 10_001, "gold"))
  end
end

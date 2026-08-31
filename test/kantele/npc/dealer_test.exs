defmodule Kantele.Npc.DealerTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.{Dealer, Vendor}

  describe "Vendor.price_string / buy_object / vendor_list" do
    test "price_string 分档" do
      assert Vendor.price_string(20_000) == "二两黄金"
      assert Vendor.price_string(300) == "三两白银"
      assert Vendor.price_string(7) == "七文铜板"
      assert Vendor.price_string(0) == "零两黄金"
    end

    test "buy_object 返回价值或 0" do
      goods = %{"sword" => %{name: "长剑", id: "changjian", value: 500}}
      assert Vendor.buy_object(goods, "sword") == 500
      assert Vendor.buy_object(goods, "nope") == 0
    end

    test "vendor_list 生成清单" do
      goods = %{"sword" => %{name: "长剑", id: "changjian", value: 500}}
      {owns, list} = Vendor.vendor_list(goods, "huizi", "huizi")
      assert owns == true
      assert list =~ "你可以购买下列这些东西："
      assert list =~ "长剑(changjian)"
      assert list =~ "五两白银"
    end
  end

  describe "Dealer.is_vendor_good" do
    test "按 id 与去色名命中" do
      goods = %{"sword" => %{name: "\e[31m长剑\e[0m", id: "changjian", value: 500}}
      assert Dealer.is_vendor_good(goods, "changjian") == "sword"
      assert Dealer.is_vendor_good(goods, "长剑") == "sword"
      assert Dealer.is_vendor_good(goods, "未知") == :error
    end
  end

  describe "Dealer.do_value (估价, x3/10 回售)" do
    test "普通物品返回回售价" do
      item = %{name: "药", value: 100}
      assert Dealer.do_value(item) == {:ok, 30}
    end

    test "consistence 成色折扣" do
      item = %{name: "药", value: 100, consistence: 50}
      assert Dealer.do_value(item) == {:ok, 15}
    end

    test "货币/人物/一文不值/不可售 拒绝" do
      assert match?({:reject, _}, Dealer.do_value(%{name: "钱", money_id: "coin"}))
      assert match?({:reject, _}, Dealer.do_value(%{name: "人", is_character?: true}))
      assert match?({:reject, _}, Dealer.do_value(%{name: "垃圾", value: 0}))
      assert match?({:reject, _}, Dealer.do_value(%{name: "宝", value: 100, no_drop?: true}))
      assert Dealer.do_value(%{name: "宝", value: 100, no_sell: "此物不售"}) == {:reject, "此物不售"}
    end
  end

  describe "Dealer.do_sell (收购, x3/10)" do
    test "普通物品回售" do
      assert Dealer.do_sell(%{name: "药", value: 200}, 1) == {:ok, 60}
    end

    test "叠加对象按 amount x base_value" do
      assert Dealer.do_sell(%{name: "药", base_value: 100, amount: 5}, 3) == {:ok, 90}
    end

    test "超出数量/减值拒绝" do
      assert match?({:reject, _}, Dealer.do_sell(%{name: "药", value: 200}, 0))
      assert match?({:reject, _}, Dealer.do_sell(%{name: "药", value: 200}, 5))
      assert match?({:reject, _}, Dealer.do_sell(%{name: "钱", value: 1, money_id: "coin"}, 1))
      assert match?({:reject, _}, Dealer.do_sell(%{name: "食", value: 10, food_supply?: true}, 1))
    end
  end

  describe "Dealer.do_buy (购买)" do
    test "默认按成本价(因子10)" do
      assert Dealer.do_buy(%{name: "剑", value: 500}, 1, %{}) == {:ok, 500}
    end

    test "现货现货价(因子12)" do
      assert Dealer.do_buy(%{name: "剑", value: 500}, 1, %{}, %{val_factor: 12}) == {:ok, 600}
    end

    test "vendor_goods 覆盖价 + 数量累加" do
      goods = %{"data/sword.c" => 1000}
      item = %{name: "剑", file: "data/sword.c", value: 500, amount: 1}
      assert Dealer.do_buy(item, 2, goods) == {:ok, 2000}
    end

    test "店东八折" do
      assert Dealer.do_buy(%{name: "剑", value: 500}, 1, %{}, %{shop_owner?: true}) == {:ok, 400}
    end

    test "超出上限/买钱 拒绝" do
      assert match?({:reject, _}, Dealer.do_buy(%{name: "剑", value: 500}, 101, %{}))
      assert match?({:reject, _}, Dealer.do_buy(%{name: "钱", value: 1, money_id: "coin"}, 1, %{}))
    end
  end

  describe "Dealer.build_list (商店清单聚合)" do
    test "库存现货 + 目录大量供应" do
      inventory = [
        %{name: "药", id: "yao", unit: "瓶", value: 100, amount: 3, base_unit: true},
        %{name: "长剑", id: "jian", unit: "把", value: 500, equipped?: true}
      ]

      goods = %{"data/sword.c" => %{name: "长剑", id: "jian", unit: "把", value: 500}}

      rows = Dealer.build_list(inventory, goods)
      assert length(rows) == 2

      yao = Enum.find(rows, &(&1.unit == "瓶"))
      assert yao.count == 3
      assert yao.price == 100
    end
  end
end

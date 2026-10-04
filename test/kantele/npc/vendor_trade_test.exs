defmodule Kantele.Npc.VendorTradeTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.Vendor

  # vendor.ex 之前只移植了 3 个纯查询，缺 `compelete_trade` ——
  # 也就是「把货真正交给买家」那一步。接上派发层后如果不补这个，
  # vendor 系商店（43 处引用）玩家付了钱但拿不到货。

  @goods %{
    "obj/jitui" => %{id: "city:jitui", name: "烤鸡腿", unit: "根", value: 80},
    "obj/baozi" => %{id: "city:baozi", name: "包子", unit: "个", value: 50}
  }

  test "命中商品 -> 产出交付计划" do
    assert {:ok, plan} = Vendor.complete_trade(@goods, "obj/jitui")

    assert plan.action == :deliver_item
    assert plan.item_id == "city:jitui"
    assert plan.name == "烤鸡腿"
    assert plan.unit == "根"
  end

  test "message 复现 LPC 的 message_vision 文案" do
    {:ok, plan} = Vendor.complete_trade(@goods, "obj/baozi")

    assert plan.message =~ "买下一"
    assert plan.message =~ "个"
    assert plan.message =~ "包子"
  end

  test "未命中 -> :not_found（LPC 里是静默跳过）" do
    assert Vendor.complete_trade(@goods, "obj/nothing") == {:error, :not_found}
  end

  test "vendor_goods 不是 map -> :not_found" do
    assert Vendor.complete_trade(nil, "obj/jitui") == {:error, :not_found}
    assert Vendor.complete_trade([], "obj/jitui") == {:error, :not_found}
  end

  test "条目不是 map -> :not_found（LPC 的 stringp 判断）" do
    assert Vendor.complete_trade(%{"x" => "notamap"}, "x") == {:error, :not_found}
  end
end
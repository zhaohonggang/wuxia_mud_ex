defmodule Kantele.Item.LiquidTest do
  use ExUnit.Case, async: false

  alias Kantele.Item.Liquid

  describe "Liquid 纯逻辑" do
    test "is_liquid? 总是 true" do
      assert Liquid.is_liquid?(%{})
    end
  end

  describe "extra_long 液量描述" do
    test "空容器返回 nil" do
      assert Liquid.extra_long(%{liquid: %{remaining: 0}}) == nil
    end

    test "装满时返回装满描述" do
      meta = %{liquid: %{remaining: 10, name: "清水", max: 10}}
      assert Liquid.extra_long(meta) == "里面装满了清水。\n"
    end

    test "五分满时返回五、六分满描述" do
      meta = %{liquid: %{remaining: 5, name: "清水", max: 10}}
      assert Liquid.extra_long(meta) == "里面装了五、六分满的清水。\n"
    end

    test "少量时返回少许描述" do
      meta = %{liquid: %{remaining: 2, name: "清水", max: 10}}
      assert Liquid.extra_long(meta) == "里面装了少许的清水。\n"
    end

    test "无 liquid 时返回 nil" do
      assert Liquid.extra_long(%{}) == nil
    end

    test "使用 max_liquid 字段" do
      meta = %{liquid: %{remaining: 5, name: "清水"}, max_liquid: 10}
      assert Liquid.extra_long(meta) == "里面装了五、六分满的清水。\n"
    end
  end
end

defmodule Kantele.World.ItemMissingDefinitionTest do
  @moduledoc """
  UG-07：物品定义缺失时不得崩掉 Foreman。

  `Kantele.World.Item.fetch/1`（原 `Items.get!/1` 的安全替代）在定义缺失时
  返回占位物品（「未知物品」），占位物品必须带 `callback_module`，让
  `item.callback_module.matches?(item, arg)` 这类消费点正常工作。

  fetch 的「定义存在 → 直返」成功路径由全部既有物品测试覆盖（成功路径
  行为与 `Items.get!/1` 完全一致），这里只专测缺失分支。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Item

  describe "fetch/1 缺失定义" do
    test "返回占位物品，保留原 id，名字可见" do
      item = Item.fetch("ghost_zone:no_such_item")

      assert is_struct(item, Kalevala.World.Item)
      assert item.id == "ghost_zone:no_such_item"
      assert item.name =~ "未知物品"
      assert item.description =~ "不在世界数据里"
    end

    test "占位物品带 callback_module，matches?/2 可调用不崩" do
      item = Item.fetch("ghost_zone:no_such_item")

      assert item.callback_module == Kantele.World.Item
      # matches? 是纯函数：对占位物品返回布尔（占位名不含 "长剑" → false），不抛
      result = item.callback_module.matches?(item, "长剑")
      assert is_boolean(result)
    end

    test "resolve/1 对缺定义实例填占位而非抛异常" do
      instance = %Kalevala.World.Item.Instance{
        id: "inst-1",
        item_id: "ghost_zone:no_such_item",
        created_at: DateTime.utc_now()
      }

      resolved = Item.resolve(instance)
      assert is_struct(resolved.item, Kalevala.World.Item)
      assert resolved.item.id == "ghost_zone:no_such_item"
    end

    test "instance_item/1 对缺定义实例返回占位而非抛异常" do
      instance = %Kalevala.World.Item.Instance{
        id: "inst-2",
        item_id: "ghost_zone:no_such_item",
        created_at: DateTime.utc_now()
      }

      item = Item.instance_item(instance)
      assert is_struct(item, Kalevala.World.Item)
      assert item.name =~ "未知物品"
    end
  end
end

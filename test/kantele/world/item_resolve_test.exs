defmodule Kantele.World.ItemResolveTest do
  use ExUnit.Case, async: false

  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items
  alias Kantele.World.Item, as: WorldItem

  @real "liuxi:baozi"
  @gone "global:potion"

  setup do
    Items.put(@real, %Item{
      id: @real,
      name: "包子 Baozi",
      description: "一个热腾腾的包子。",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{unit: "个"}
    })

    :ok
  end

  defp instance(item_id) do
    %Instance{
      id: "inst-#{item_id}",
      item_id: item_id,
      item: %Item.ItemNotLoaded{},
      meta: %{}
    }
  end

  describe "fetch/1 —— 定义缺失时不 raise" do
    test "有定义时返回真物品" do
      item = WorldItem.fetch(@real)

      assert item.id == @real
      assert item.name == "包子 Baozi"
    end

    test "没定义时返回占位物品而不是抛异常" do
      # 这条是回归测试：`test` / `global` 两个夹具区搬走之后，数据库里
      # 还留着 `global:potion` 这种 item_id。曾经 `Items.get!/1` 在这里
      # raise「Could not find key global:potion in cache」，把登录中的
      # Foreman GenServer 整个带走。
      assert WorldItem.fetch(@gone) == %Item{
               id: @gone,
               name: "未知物品（global:potion）",
               description: "这件物品的定义不在世界数据里。",
               meta: %{}
             }
    end

    test "对完全没见过的 id 也一样不炸" do
      assert %Item{id: "no:such_thing"} = WorldItem.fetch("no:such_thing")
    end
  end

  describe "resolve/1" do
    test "填上真定义" do
      resolved = WorldItem.resolve(instance(@real))

      assert resolved.item.name == "包子 Baozi"
      assert resolved.id == "inst-#{@real}"
    end

    test "定义缺失时填占位物品，实例本身保持不变" do
      original = instance(@gone)
      resolved = WorldItem.resolve(original)

      assert resolved.item.id == @gone
      assert resolved.item_id == @gone
      assert resolved.meta == %{}
    end
  end

  describe "背包渲染不再受缺失定义影响" do
    test "同时有真物品和悬空物品时都能列出来" do
      # InventoryEvent.list/2 用的是 WorldItem.resolve/1，所以这里覆盖的是
      # 「登录时列背包」这条路径 —— 之前只要有一件查不到定义的角色就登不进来。
      resolved =
        [instance(@real), instance(@gone)]
        |> Enum.map(&WorldItem.resolve/1)
        |> Enum.map(& &1.item.name)

      assert resolved == ["包子 Baozi", "未知物品（global:potion）"]
    end
  end
end

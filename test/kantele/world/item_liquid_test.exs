defmodule Kantele.World.Item.LiquidTest do
  use ExUnit.Case, async: true

  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Item.Liquid
  alias Kantele.World.Item.Meta

  defp item(liquid, max_liquid \\ nil) do
    %Item{
      id: "test:jiudai",
      name: "酒袋",
      meta: %Meta{liquid: liquid, max_liquid: max_liquid}
    }
  end

  defp instance(meta \\ %{}) do
    %Instance{id: "inst-1", item_id: "test:jiudai", created_at: DateTime.utc_now(), meta: meta}
  end

  @liquid %{type: "alcohol", name: "米酒", remaining: 15, drunk_apply: 3}

  describe "definition/1" do
    test "有 liquid 的定义返回原表" do
      assert Liquid.definition(item(@liquid)) == @liquid
    end

    test "无 liquid 返回 nil（药水/普通物品）" do
      assert Liquid.definition(%Item{id: "x", name: "药", meta: %Meta{}}) == nil
      assert Liquid.definition(%Item{id: "x", name: "药", meta: %{}}) == nil
      assert Liquid.definition(nil) == nil
    end
  end

  describe "state/2" do
    test "实例没有液体键时退回定义值" do
      state = Liquid.state(item(@liquid), instance())

      assert state.remaining == 15
      assert state.name == "米酒"
      assert state.type == "alcohol"
      assert state.drunk_apply == 3
    end

    test "实例键优先于定义（喝过之后以实例为准）" do
      state = Liquid.state(item(@liquid), instance(%{"liquid_remaining" => 4}))

      assert state.remaining == 4
      # 其余字段仍取定义
      assert state.name == "米酒"
    end

    test "实例可覆盖 name/type（fill 灌成清水）" do
      state =
        Liquid.state(
          item(@liquid),
          instance(%{"liquid_name" => "清水", "liquid_type" => "water"})
        )

      assert state.name == "清水"
      assert state.type == "water"
    end

    test "max 优先取 liquid.max，其次取 max_liquid" do
      assert Liquid.state(item(Map.put(@liquid, :max, 20), 15), instance()).max == 20
      assert Liquid.state(item(@liquid, 15), instance()).max == 15
    end

    test "非容器返回 nil" do
      assert Liquid.state(%Item{id: "x", name: "药", meta: %Meta{}}, instance()) == nil
    end
  end

  describe "put_state/2 与 empty?/1" do
    test "只写四个液体键，其余实例 meta 原样保留" do
      inst = instance(%{"book" => :keep})
      updated = Liquid.put_state(inst, %{remaining: 7, name: "清水", type: "water", drunk_apply: 2})

      assert updated.meta["liquid_remaining"] == 7
      assert updated.meta["liquid_name"] == "清水"
      assert updated.meta["liquid_type"] == "water"
      assert updated.meta["liquid_drunk_apply"] == 2
      assert updated.meta["book"] == :keep
    end

    test "name/type 为 nil 时不写键（避免存 nil 覆盖定义回退）" do
      updated = Liquid.put_state(instance(), %{remaining: 1, name: nil, type: nil, drunk_apply: 0})

      assert updated.meta["liquid_remaining"] == 1
      refute Map.has_key?(updated.meta, "liquid_name")
      refute Map.has_key?(updated.meta, "liquid_type")
    end

    test "empty?：0 与负数算空，正数不算" do
      assert Liquid.empty?(%{remaining: 0})
      assert Liquid.empty?(%{remaining: -1})
      refute Liquid.empty?(%{remaining: 1})
      assert Liquid.empty?(%{remaining: nil})
    end
  end

  describe "serialize/1 与 restore/2（背包持久化）" do
    test "serialize 只输出液体键" do
      inst =
        instance(%{
          "liquid_remaining" => 3,
          "liquid_name" => "米酒",
          "liquid_type" => "alcohol",
          "liquid_drunk_apply" => 3,
          "book" => :not_serialized
        })

      assert Liquid.serialize(inst) == %{
               "liquid_remaining" => 3,
               "liquid_name" => "米酒",
               "liquid_type" => "alcohol",
               "liquid_drunk_apply" => 3
             }
    end

    test "无液体键的实例 serialize 为空表（旧格式）" do
      assert Liquid.serialize(instance()) == %{}
    end

    test "restore 把存档里的液体键合并回实例" do
      entry = %{"item_id" => "test:jiudai", "liquid_remaining" => 2, "liquid_name" => "米酒"}
      restored = Liquid.restore(instance(), entry)

      assert restored.meta["liquid_remaining"] == 2
      assert restored.meta["liquid_name"] == "米酒"
      refute Map.has_key?(restored.meta, "liquid_type")
    end

    test "restore 对旧存档（只有 item_id）原样返回" do
      inst = instance()
      assert Liquid.restore(inst, %{"item_id" => "test:jiudai"}) == inst
      assert Liquid.restore(inst, nil) == inst
    end

    test "serialize → restore 往返一致" do
      inst = Liquid.put_state(instance(), %{remaining: 9, name: "米酒", type: "alcohol", drunk_apply: 3})
      entry = Map.merge(%{"item_id" => inst.item_id}, Liquid.serialize(inst))
      restored = Liquid.restore(instance(), entry)

      assert Liquid.serialize(restored) == Liquid.serialize(inst)
    end
  end
end

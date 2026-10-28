defmodule Kantele.World.ForgeMaterialMetaTest do
  @moduledoc """
  S0 验证：Item.Meta 新增的锻造原料字段（material_attrib / material_name /
  item_make）能被 loader 正确解析；缺省时回落 nil / false。
  """
  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  @forge_material %{
    name: "玄铁石",
    description: "一块黑黝黝的石头。",
    meta: %{
      material_attrib: "steel",
      material_name: "玄铁",
      item_make: true,
      can_make: ["all"],
      not_make: ["鞭", "战衣", "锤", "腰带"],
      power_point: 70,
      item_origin: 1
    }
  }

  test "parse_item 读取锻造原料字段" do
    {_key, item} = Loader.parse_item(%{id: "item"}, "xuantie", @forge_material, %{})

    assert item.meta.material_attrib == "steel"
    assert item.meta.material_name == "玄铁"
    assert item.meta.item_make == true
    assert item.meta.can_make == ["all"]
    assert item.meta.power_point == 70
  end

  test "缺省锻造字段回落 nil / false" do
    item_data = %{name: "普通石头", description: "x", meta: %{}}

    {_key, item} = Loader.parse_item(%{id: "item"}, "rock", item_data, %{})

    assert item.meta.material_attrib == nil
    assert item.meta.material_name == nil
    assert item.meta.item_make == false
  end
end

defmodule Kantele.World.Loader.ObjectSetsTest do
  use ExUnit.Case, async: true
  alias Kantele.World.Loader

  @tag :world
  test "room_object_sets picks one branch at load time" do
    Kantele.World.Loader.reset_unresolved_warnings()
    world = Loader.load()
    
    # taohua:daojufang has 3 branches, each with 2 yapu + varying items
    daojufang_zone = Enum.find(world.zones, &(&1.id == "taohua"))
    daojufang = Enum.find(daojufang_zone.rooms, fn r -> r.id == "taohua:daojufang" end)
    
    assert daojufang != nil
    # Characters are at world level, filter by room_id
    chars_in_room = Enum.filter(world.characters, &(&1.room_id == "taohua:daojufang"))
    # Should have exactly 2 characters (all branches have 2 yapu)
    assert length(chars_in_room) == 2
    
    # Should have at least 1 item (branches have 1, 2, or 3 items)
    assert length(daojufang.item_instances) >= 1
    assert length(daojufang.item_instances) <= 3
    
    # wudu:dongxue has 2 branches: duanchang OR tongpai
    dongxue_zone = Enum.find(world.zones, &(&1.id == "wudu"))
    dongxue = Enum.find(dongxue_zone.rooms, fn r -> r.id == "wudu:dongxue" end)
    
    assert dongxue != nil
    item_ids = Enum.map(dongxue.item_instances, & &1.item_id)
    # Should have exactly one of duanchang or tongpai
    assert Enum.any?(item_ids, &String.contains?(&1, "duanchang")) ||
           Enum.any?(item_ids, &String.contains?(&1, "tongpai"))
    assert length(item_ids) == 1
  end
end
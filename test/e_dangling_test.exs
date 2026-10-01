defmodule EDanglingTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Loader

  # The two cross-zone exits that used to be dangling (checklist item E).  Both are
  # resolved now, and neither needed the LPC corpus to change:
  #
  #   baituo/gebi -east-> /d/xiyu/shamo10        restored by the macro-inherit fix
  #   city/guangchang -liuxi-> /d/minimal_world/guangchang
  #       minimal_world is deliberately not converted, so the converter recovers the
  #       destination zone from the exit DIRECTION: "liuxi" is the installed zone id
  #       of 柳溪镇.  Room-name matching is not usable here - "guangchang" is the
  #       town square of a dozen zones.
  @moduledoc "Checklist item E: both formerly-dangling cross-zone exits now resolve."

  @tag :world_data
  test "baituo/gebi east reaches xiyu/shamo10" do
    world = Loader.load()
    gebi = Enum.find(world.rooms, fn r -> r.id == "baituo:gebi" end)
    east = Enum.find(gebi.exits, fn e -> e.exit_name == "east" end)

    assert east != nil, "gebi lost its east exit"

    assert east.end_room_id == "xiyu:shamo10",
           "gebi -east-> should be xiyu:shamo10, got #{inspect(east.end_room_id)}"
  end

  @tag :world_data
  test "city/guangchang liuxi exit now reaches liuxi/guangchang" do
    world = Loader.load()
    gc = Enum.find(world.rooms, fn r -> r.id == "city:guangchang" end)
    liuxi = Enum.find(gc.exits, fn e -> e.exit_name == "liuxi" end)

    assert Enum.any?(world.rooms, fn r -> r.id == "liuxi:guangchang" end),
           "precondition: liuxi:guangchang should exist"

    assert liuxi != nil,
           "city:guangchang lost its liuxi exit - the direction-name recovery stopped working"

    assert liuxi.end_room_id == "liuxi:guangchang",
           "guangchang -liuxi-> should be liuxi:guangchang, got #{inspect(liuxi.end_room_id)}"
  end

  @tag :world_data
  test "liuxi/guangchang has a way back to city/guangchang" do
    world = Loader.load()
    lg = Enum.find(world.rooms, fn r -> r.id == "liuxi:guangchang" end)

    assert Enum.any?(lg.exits, fn e -> e.end_room_id == "city:guangchang" end),
           """
           liuxi:guangchang has no way back to the city, so the round trip is broken.
           exits: #{inspect(Enum.map(lg.exits, &{&1.exit_name, &1.end_room_id}))}
           """
  end
end
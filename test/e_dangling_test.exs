defmodule EDanglingTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Loader

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
  test "city/guangchang liuxi exit is still dangling" do
    world = Loader.load()
    gc = Enum.find(world.rooms, fn r -> r.id == "city:guangchang" end)
    liuxi = Enum.find(gc.exits, fn e -> e.exit_name == "liuxi" end)

    IO.puts("city:guangchang -liuxi-> #{inspect(liuxi)}")

    # liuxi:guangchang DOES exist, but the reference is written with the LPC
    # directory name (minimal_world) instead of the zone id (liuxi), so
    # dereference/3 finds no such zone and drops the exit.
    assert Enum.any?(world.rooms, fn r -> r.id == "liuxi:guangchang" end),
           "precondition: liuxi:guangchang should exist"

    assert liuxi == nil,
           "expected the liuxi exit to still be dangling (minimal_world != liuxi)"
  end
end

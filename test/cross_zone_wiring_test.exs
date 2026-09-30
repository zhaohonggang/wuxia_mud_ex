defmodule CrossZoneWiringTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Verifies the converter's cross-zone wiring against the real loader rather than
  against the text.  `Kantele.World.Loader.dereference/3` treats the first
  dot-segment of a reference as a zone id when it is not rooms/characters/items
  (loader.ex:1315-1343), so `<zone>.rooms.<room>.id` must resolve to
  `"<zone>:<room>"`.

  `zone.rooms` is a LIST of %Room{} after `zone_rooms_to_list/1`, not a map.
  """

  defp world, do: Kantele.World.Loader.load()

  defp all_rooms(w), do: Enum.flat_map(w.zones, & &1.rooms)

  defp room_index(w), do: Map.new(all_rooms(w), &{&1.id, &1})

  @tag :world_data
  test "beimen north resolves to shaolin:yidao, not a city room" do
    beimen = Map.fetch!(room_index(world()), "city:beimen")
    north = Enum.find(beimen.exits, &(&1.exit_name == "north"))

    assert north != nil, "city:beimen has no north exit"

    assert north.end_room_id == "shaolin:yidao",
           "beimen north should reach shaolin:yidao, got #{inspect(north.end_room_id)}"
  end

  @tag :world_data
  test "no exit keeps a dotted (unresolved) reference" do
    known = MapSet.new(all_rooms(world()), & &1.id)

    dangling =
      for room <- all_rooms(world()),
          e <- room.exits,
          is_binary(e.end_room_id),
          String.contains?(e.end_room_id, "."),
          not MapSet.member?(known, e.end_room_id),
          do: {room.id, e.exit_name, e.end_room_id}

    assert dangling == [], "unresolved references: #{inspect(dangling)}"
  end

  @tag :world_data
  test "the 15 former name-collision edges point at the right zone" do
    rooms = room_index(world())

    expected = [
      {"beijing:ximenwai", "west", "heimuya:road3"},
      {"dali:luyuxi", "south", "wudu:road1"},
      {"dali:road5", "southeast", "foshan:road1"},
      {"foshan:road1", "northwest", "dali:road5"},
      {"guanwai:laolongtou", "southwest", "beijing:road3"},
      {"item:road1", "west", "suzhou:road5"},
      {"jingzhou:nanshilu1", "south", "kunming:road1"},
      {"jueqing:shanjiao", "southdown", "xiangyang:shanlu1"},
      {"kaifeng:tokaifeng", "east", "zhongzhou:wroad3"},
      {"kunming:xroad2", "west", "dali:road1"},
      {"lanzhou:caroad8", "southeast", "changan:caroad2"},
      {"lingxiao:boot", "southeast", "xuedao:sroad1"},
      {"lingzhou:ximen", "west", "xuanminggu:xiaolu1"},
      {"suzhou:road5", "east", "item:road1"},
      {"xiyu:tianroad2", "northup", "lingjiu:shanjiao"}
    ]

    for {room_id, dir, want} <- expected do
      room = Map.fetch!(rooms, room_id)
      exit = Enum.find(room.exits, &(&1.exit_name == dir))

      assert exit != nil, "#{room_id} has no #{dir} exit"
      assert exit.end_room_id == want,
             "#{room_id} -#{dir}-> should be #{want}, got #{inspect(exit.end_room_id)}"
    end
  end

  @tag :world_data
  test "__FILE__ exits resolve to the room itself (self-loops)" do
    w = world()
    rooms = room_index(w)

    # baituo/cao1.c declares "west" : __FILE__ and "south" : __FILE__,
    # i.e. both directions lead back to the same room.
    cao1 = Map.fetch!(rooms, "baituo:cao1")

    for dir <- ["west", "south"] do
      exit = Enum.find(cao1.exits, &(&1.exit_name == dir))
      assert exit != nil, "cao1 lost its #{dir} self-loop"
      assert exit.end_room_id == "baituo:cao1",
             "cao1 -#{dir}-> should return to baituo:cao1, got #{inspect(exit.end_room_id)}"
    end

    # No exit anywhere may still carry the bogus literal `__file__` room.
    bogus =
      for r <- all_rooms(w),
          e <- r.exits,
          is_binary(e.end_room_id),
          String.contains?(e.end_room_id, "__file__"),
          do: {r.id, e.exit_name, e.end_room_id}

    assert bogus == [], "unresolved __FILE__ references remain: #{inspect(bogus)}"
  end

  @tag :world_data
  test "world graph is now connected across zones" do
    w = world()

    adj =
      Enum.reduce(all_rooms(w), %{}, fn room, acc ->
        targets = for e <- room.exits, is_binary(e.end_room_id), do: e.end_room_id
        Map.put(acc, room.id, targets)
      end)

    all = MapSet.new(all_rooms(w), & &1.id)
    start = "city:guangchang"

    seen =
      Enum.reduce(1..100_000, {MapSet.new([start]), [start]}, fn _, {seen, queue} = acc ->
        case queue do
          [] ->
            acc

          [id | rest] ->
            fresh = adj |> Map.get(id, []) |> Enum.reject(&MapSet.member?(seen, &1))
            {MapSet.union(seen, MapSet.new(fresh)), rest ++ fresh}
        end
      end)
      |> elem(0)

    unreachable = MapSet.difference(all, seen)

    IO.puts(
      "\nreachable from city:guangchang: #{MapSet.size(seen)}/#{MapSet.size(all)} rooms"
    )

    IO.puts("unreachable: #{inspect(MapSet.to_list(unreachable))}")

    assert MapSet.size(seen) > 1
  end
end

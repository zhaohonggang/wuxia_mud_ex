defmodule RuntimePickItemTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Loader

  @moduledoc """
  An LPC room key written as `"<path>" + random(n)` makes the driver evaluate
  random(n) ONCE when the room is created, so the room ends up holding exactly
  one of the n candidates.  The converter therefore writes the alternatives as a
  list and the loader picks one:

      emei/cangjingge.c
        __DIR__"obj/fojing1" + random(2) : 1,
        __DIR__"obj/fojing2" + random(2) : 1,

      data/world/emei.ucl
        { id = [items.fojing10.id,items.fojing11.id] },
        { id = [items.fojing20.id,items.fojing21.id] }

  Emitting all four candidates instead (an earlier attempt) would put four
  fojings in the room where the MUD puts two.
  """

  defp room_items(world, zone_id, room_id) do
    zone = Enum.find(world.zones, &(&1.id == zone_id))
    room = Enum.find(zone.rooms, &(&1.id == room_id))
    Map.get(room, :item_instances, [])
  end

  @tag :world_data
  test "cangjingge 拿两件佛经，每件来自一个 random() 候选组" do
    items = room_items(Loader.load(), "emei", "emei:cangjingge")
    fojings = Enum.filter(items, &String.contains?(&1.item_id, "fojing"))

    assert length(fojings) == 2,
           "expected 2 fojings (one per random key), got #{inspect(fojings)}"

    assert Enum.any?(fojings, &String.contains?(&1.item_id, "fojing1")),
           "missing the fojing1x pick, got #{inspect(fojings)}"

    assert Enum.any?(fojings, &String.contains?(&1.item_id, "fojing2")),
           "missing the fojing2x pick, got #{inspect(fojings)}"
  end

  @tag :world_data
  test "候选组里的物品都真实存在（fojing10/11/20/21）" do
    ids = Loader.load() |> Map.get(:items) |> Enum.map(& &1.id) |> MapSet.new()

    for suffix <- ~w(fojing10 fojing11 fojing20 fojing21) do
      assert MapSet.member?(ids, "shaolin:#{suffix}"),
             "shaolin:#{suffix} missing - the candidate list names an item that does not exist"
    end
  end

  @tag :world_data
  test "没有任何房间的物品引用是不可解析的候选列表" do
    world = Loader.load()

    unresolved =
      for r <- world.rooms,
          inst <- Map.get(r, :item_instances, []),
          is_nil(inst.item_id),
          do: r.id

    assert unresolved == [], "rooms with unresolvable item instances: #{inspect(unresolved)}"
  end

  @tag :world_data
  test "shaolin:cjlou1 产生 4 个 wuji 书实例，item_id 为 wuji1~4" do
    items = room_items(Loader.load(), "shaolin", "shaolin:cjlou1")
    wuji = Enum.filter(items, &String.contains?(&1.item_id, "wuji"))

    assert length(wuji) == 4,
           "expected 4 wuji instances, got #{inspect(wuji)}"

    ids = Enum.map(wuji, & &1.item_id) |> Enum.sort()
    assert ids == ["clone_lib:wuji1", "clone_lib:wuji2", "clone_lib:wuji3", "clone_lib:wuji4"],
           "item_ids should be the 4 wuji variants, got #{inspect(ids)}"
  end
end

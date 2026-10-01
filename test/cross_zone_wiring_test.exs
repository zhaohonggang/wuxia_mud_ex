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

  # ---------------------------------------------------------------------------
  # Cross-zone reciprocity
  # ---------------------------------------------------------------------------

  # Directions that have no opposite.  in/out is a portal pair, river is a boat
  # action, and liuxi/yangzhou are named after the destination town (LPC's own
  # wording: 「镇口东北方向的官道(yangzhou)直通扬州府」).
  @custom_dirs MapSet.new(~w(in out go_in enter climb river liuxi yangzhou))

  @opposites %{
    "north" => "south",
    "south" => "north",
    "east" => "west",
    "west" => "east",
    "up" => "down",
    "down" => "up",
    "northeast" => "southwest",
    "southwest" => "northeast",
    "northwest" => "southeast",
    "southeast" => "northwest",
    "northup" => "southdown",
    "southdown" => "northup",
    "southup" => "northdown",
    "northdown" => "southup",
    "eastup" => "westdown",
    "westdown" => "eastup",
    "eastdown" => "westup",
    "westup" => "eastdown"
  }

  # Every cross-zone edge the LPC source itself leaves one-way, as
  # {source room, direction, target room}.  Each was verified by re-reading the
  # TARGET's own set("exits") under C:/files/git/mud/d: none of them declares a way
  # back, so no reverse exit may be invented (SOP: 不要在转换器里"发明"目标).
  @one_way [
    # 目标房根本没有 set("exits") —— xiyu/shamo10.c 只写了 short/long。
    # 从 gebi 向东走进沙漠尽头，只能靠 shamo10 自己的 up/down 在沙海内移动。
    {"baituo:gebi", "east", "xiyu:shamo10"},

    # 密室/迷宫的脱身出口，通往 city:guangchang 是单向逃逸
    {"gumu:mishi8", "out", "city:guangchang"},
    {"mingjiao:didao2", "out", "lanzhou:guangchang"},
    {"quanzhen:mishi", "eastup", "city:guangchang"},
    {"register:roome", "out", "city:guangchang"},
    {"register:roomn", "out", "city:guangchang"},
    {"register:rooms", "out", "city:guangchang"},
    {"register:roomw", "out", "city:guangchang"},

    # 垂直向上的单向支线：目标房只朝本区内部开路（山道顶、密道顶、洞窟顶）
    {"city:xdmidao1", "up", "xuedao:sroad8"},
    {"emei:midao5", "up", "chengdu:qingyanggong"},
    {"jinshe:shanbi", "up", "huashan:ziqitai"},
    {"wudu:midao5", "up", "city:ma_chufang"},
    {"death:god1", "down", "city:wumiao"},
    {"tulong:jiulou", "down", "beijing:huiying"},

    # 走廊尽头的死胡同支线：目标区的回程出口指向别处
    {"baituo:midao", "east", "city:beidajie1"},
    {"huanghe:liupanshan", "eastdown", "village:wexit"},
    {"meizhuang:hupan", "west", "quanzhou:nanhu1"},
    {"suzhou:taihu", "west", "yanziwu:hupan"},
    {"xiakedao:xkroad1", "northup", "hengyang:hsroad9"},
    {"tianlongsi:dadao1", "northeast", "emei:qsjie2"},

    # 两个区各有一个同名 bridge 房：heimuya:bridge 的出口落进 baituo:xijie，而
    # baituo/xijie.c 的 "west" : __DIR__"bridge" 按 MudOS 语义解析到 baituo:bridge，
    # 于是回不到 heimuya:bridge。源码级同名歧义，不是转换缺陷。
    {"heimuya:bridge", "northwest", "baituo:guangchang"},
    {"heimuya:bridge", "east", "baituo:xijie"},

    # 非 mud 语料区（手工维护），不参与 LPC 对照
    {"tulong:haigang", "west", "beijing:road10"}
  ]

  # Two-way edges whose reverse direction is deliberately NOT the opposite compass.
  @asymmetric %{
    # caoyuan5 有 south 与 southwest 两个方向都通 nanjiang2，而 nanjiang2 只有
    # northeast 一条回程 —— 源码即如此，走 south 进来只能走 northeast 出去。
    "shenfeng:caoyuan5" => %{"south" => "northeast"},
    # signature 与 liuxi 都是手工维护区，两侧都叫 north：向北进隐世之境，
    # 再向北回来。方向语义不理想但不是转换缺陷。
    "signature:yinyi" => %{"north" => "north"},
    "liuxi:guangchang" => %{"north" => "north"}
  }

  defp cross_zone_edges(w) do
    for room <- all_rooms(w),
        e <- room.exits,
        is_binary(e.end_room_id),
        zone = e.end_room_id |> String.split(":") |> List.first(),
        zone != room.id |> String.split(":") |> List.first(),
        do: {room.id, to_string(e.exit_name), e.end_room_id}
  end

  defp back_directions(w, src, tgt) do
    case Map.fetch(room_index(w), tgt) do
      {:ok, room} -> for e <- room.exits, e.end_room_id == src, do: to_string(e.exit_name)
      :error -> []
    end
  end

  @tag :world_data
  test "every one-way cross-zone edge is a known LPC source quirk" do
    w = world()
    known = MapSet.new(@one_way, fn {src, dir, tgt} -> {src, dir, tgt} end)

    unknown =
      for {src, dir, tgt} <- cross_zone_edges(w),
          back_directions(w, src, tgt) == [],
          not MapSet.member?(known, {src, dir, tgt}),
          do: {src, dir, tgt}

    assert unknown == [],
           """
           cross-zone edges with no way back that are not on the allowlist.
           Either the converter dropped a reverse exit, or a new one-way edge
           appeared - add it to @one_way with the reason, do not invent the exit:
           #{inspect(unknown)}
           """
  end

  @tag :world_data
  test "two-way cross-zone edges use the opposite direction name" do
    w = world()
    known_asym = Enum.flat_map(@asymmetric, fn {src, pairs} ->
      for {dir, _back} <- pairs, do: {src, dir}
    end)

    wrong =
      for {src, dir, tgt} <- cross_zone_edges(w),
          back = back_directions(w, src, tgt),
          back != [],
          not MapSet.member?(@custom_dirs, dir),
          @opposites[dir] not in back,
          not Enum.any?(known_asym, &(elem(&1, 0) == src and elem(&1, 1) == dir)),
          do: {src, dir, tgt, back}

    assert wrong == [],
           """
           two-way edges whose reverse direction is neither the opposite compass
           nor a known deliberate exception:
           #{inspect(wrong)}
           """
  end

  @tag :world_data
  test "the one-way allowlist still describes reality" do
    w = world()
    edges = MapSet.new(cross_zone_edges(w))

    stale =
      for {src, _dir, tgt} = edge <- @one_way,
          MapSet.member?(edges, edge),
          back_directions(w, src, tgt) != [],
          do: edge

    gone = @one_way -- Enum.to_list(edges)

    assert stale == [] and gone == [],
           """
           the one-way allowlist drifted. `stale` entries now have a way back and
           can be removed; `gone` entries no longer exist as cross-zone edges:
           stale=#{inspect(stale)} gone=#{inspect(gone)}
           """
  end
end

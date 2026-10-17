# P3-b/R6 verification: the no_steal/no_fight/no_search flag fix on real data.
# Before the fix, `context.data.no_steal` (and .no_fight/.skybook/.no_search)
# raised KeyError on every steal/attempt and search/attempt, because the Room
# struct has only `flags` (a string list), not those fields.
# Read-only; run inside the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_no_steal_flag.exs

defmodule Probe do
  alias Kalevala.Event
  alias Kalevala.World.Room.Context

  def requester do
    %Kalevala.Character{
      id: "player-1",
      name: "测试侠客",
      pid: self(),
      room_id: "probe:room",
      inventory: [],
      attributes: %{"qi" => 100, "jing" => 100, "score" => 0},
      meta: %{}
    }
  end

  def context(room) do
    %Context{
      data: room,
      characters: [requester()],
      item_instances: [],
      assigns: %{},
      events: [],
      output: []
    }
  end

  def event(topic, data) do
    %Event{from_pid: self(), topic: topic, data: data}
  end

  def texts(ctx) do
    Enum.flat_map(ctx.output, fn
      {_pid, %Kalevala.Character.Conn.Text{data: data}} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
  end
end

world = Kantele.World.Loader.load()

rooms = Enum.flat_map(world.zones, fn zone -> zone.rooms end)

with_flag = fn flag ->
  Enum.filter(rooms, fn r -> flag in (Map.get(r, :flags) || []) end)
end

no_steal_rooms = with_flag.("no_steal")
no_fight_rooms = with_flag.("no_fight")
no_search_rooms = with_flag.("no_search")
plain_room = Enum.find(rooms, fn r -> (Map.get(r, :flags) || []) == [] end)

IO.puts("rooms total                 : #{length(rooms)}")
IO.puts("rooms with no_steal         : #{length(no_steal_rooms)}")
IO.puts("rooms with no_fight         : #{length(no_fight_rooms)}")
IO.puts("rooms with no_search        : #{length(no_search_rooms)}")
IO.puts("Room struct has :flags      : #{Map.has_key?(%Kantele.World.Room{}, :flags)}")
IO.puts("Room struct has :no_steal   : #{Map.has_key?(%Kantele.World.Room{}, :no_steal)} (bug field)")

steal_ctx =
  Kantele.World.Room.StealRequestEvent.call(Probe.context(hd(no_steal_rooms)), Probe.event("steal/attempt", %{item: "剑", target: "李四"}))

IO.puts("steal in real no_steal room : #{inspect(Probe.texts(steal_ctx))}")

steal_plain =
  Kantele.World.Room.StealRequestEvent.call(Probe.context(plain_room), Probe.event("steal/attempt", %{item: "剑", target: "李四"}))

IO.puts("steal in unflagged room     : #{inspect(Probe.texts(steal_plain))}")

search_plain =
  Kantele.World.Room.SearchRequestEvent.call(Probe.context(plain_room), Probe.event("search/attempt", %{}))

IO.puts("search in unflagged room    : #{inspect(Probe.texts(search_plain))}")

search_flagged =
  Kantele.World.Room.SearchRequestEvent.call(
    Probe.context(%{hd(no_steal_rooms) | flags: ["no_search"]}),
    Probe.event("search/attempt", %{})
  )

IO.puts("search in no_search room    : #{inspect(Probe.texts(search_flagged))}")

IO.puts("has_flag? real room/flag    : #{inspect([
  Kantele.World.Room.has_flag?(hd(no_steal_rooms), "no_steal"),
  Kantele.World.Room.has_flag?(plain_room, "no_steal")
])}")

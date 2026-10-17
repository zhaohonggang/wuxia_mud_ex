# P3-a verification: equipment-message consumer wiring end to end on real data.
# Confirms that Item.Meta.messages (B5a converter output + B5b backfill) actually
# reaches the new room-vision path (VisionEvent/VisionView) with the same
# substitution semantics the command uses.
# Read-only; run inside the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_equip_messages_wiring.exs

alias Kalevala.Event
alias Kantele.Character.VisionEvent
alias Kantele.Character.VisionView

world = Kantele.World.Loader.load()

messages_of = fn it ->
  case it.meta do
    %{messages: m} when is_map(m) and map_size(m) > 0 -> m
    _ -> nil
  end
end

with_msgs = Enum.filter(world.items, &(messages_of.(&1) != nil))

IO.puts("items with messages : #{length(with_msgs)} / #{length(world.items)}")

# 1. key coverage (expected: wield 218 / unwield 155 / wear 22 / remove 13 / unequip 31)
for k <- [:wield, :unwield, :wear, :remove, :unequip] do
  c = Enum.count(with_msgs, fn it -> Map.has_key?(messages_of.(it), k) end)
  IO.puts("  key #{String.pad_trailing(to_string(k), 8)}: #{c}")
end

# 2. placeholders: every template must only use {npc}/{name}
bad =
  Enum.flat_map(with_msgs, fn it ->
    messages_of.(it)
    |> Map.values()
    |> Enum.reject(fn t -> String.contains?(t, "{npc}") or String.contains?(t, "{name}") end)
    |> Enum.map(fn t -> {it.id, t} end)
  end)

IO.puts("templates without {npc}/{name} (OK, plain text) : #{length(bad)}")

# 3. end-to-end on a real sample: command-side substitution + VisionView renders
sample = Enum.find(with_msgs, fn it -> Map.has_key?(messages_of.(it), :wield) end)

case sample do
  nil ->
    IO.puts("!! no item with wield message")

  it ->
    template = Map.fetch!(messages_of.(it), :wield)
    text = String.replace(template, "{name}", it.name)

    IO.puts("sample item          : #{it.id} (#{it.name})")
    IO.puts("template             : #{template}")
    IO.puts("after {name} subst   : #{text}")

    actor = %Kalevala.Character{id: "player-x", name: "测试侠客", room_id: "test:room"}

    echo =
      VisionView.render("echo", %{text: text})
      |> Map.get(:text)
      |> IO.iodata_to_binary()

    listen =
      VisionView.render("listen", %{text: text, character: actor})
      |> Map.get(:text)
      |> IO.iodata_to_binary()

    IO.puts("actor sees           : #{echo}")
    IO.puts("room sees            : #{listen}")

    if echo == listen do
      IO.puts("!! echo/listen identical -- {npc} substitution broken")
    else
      IO.puts("echo/listen differ   : ok ({npc} rendered per recipient)")
    end

    # 4. router gate: the published event must be routed to VisionEvent
    event = %Event{
      from_pid: self(),
      topic: Event.Message,
      data: %Event.Message{
        channel_name: "rooms:#{actor.room_id}",
        type: "vision",
        text: text,
        character: actor,
        id: "probe-1"
      }
    }

    IO.puts("VisionEvent.interested?: #{VisionEvent.interested?(event)}")

    event_speech = %{event | data: %{event.data | type: "speech"}}
    IO.puts("interested? (speech)      : #{VisionEvent.interested?(event_speech)}")
end

# B5a verification: the converter already emits `messages = { wield, unwield }`
# for items (lpc_converter.ex L3253). This probe confirms the loader now carries
# them into Item.Meta.messages. Read-only; run inside the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_item_messages.exs

world = Kantele.World.Loader.load()

items = world.items

msgs = fn it ->
  case it.meta do
    %{messages: m} when is_map(m) and map_size(m) > 0 -> m
    _ -> nil
  end
end

with_msgs = Enum.filter(items, &(msgs.(&1) != nil))

IO.puts("items total          : #{length(items)}")
IO.puts("items with messages  : #{length(with_msgs)}")

for k <- [:wield, :unwield, :wear, :remove, :unequip] do
  c = Enum.count(with_msgs, fn it -> Map.has_key?(msgs.(it), k) end)
  IO.puts("  with #{String.pad_trailing(to_string(k), 8)}: #{c}")
end

case with_msgs do
  [] ->
    IO.puts("!! no messages loaded -- check loader parse_item")

  [it | _] ->
    IO.puts("sample id            : #{it.id}")
    IO.inspect(msgs.(it), label: "sample messages")
end

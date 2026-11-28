alias Kantele.World.Loader
world = Loader.load()
items = Map.new(world.items, fn i -> {i.id, true} end)

world.characters
|> Enum.flat_map(fn ch ->
  meta = ch.meta
  carry = (is_struct(meta) and meta.carry) || (is_map(meta) and Map.get(meta, :carry)) || []
  carry
  |> Enum.filter(&is_binary/1)
  |> Enum.filter(&String.contains?(&1, ":"))
  |> Enum.reject(&Map.has_key?(items, &1))
  |> Enum.map(fn ref ->
    zone = (is_struct(meta) and meta.zone_id) || "?"
    "#{zone}:#{ch.name} -> #{ref}"
  end)
end)
|> Enum.uniq()
|> Enum.each(&IO.puts/1)

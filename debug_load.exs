world = Kantele.World.Loader.load()
IO.puts("LOADED zones: #{length(world.zones)}")

test_zone = Enum.find(world.zones, &(&1.id == "test"))

if test_zone do
  IO.puts("ZONE test: rooms=#{length(test_zone.rooms)} items=#{length(test_zone.items)} chars=#{map_size(test_zone.characters)}")
end

damen = Enum.find(test_zone.rooms, &(&1.key == "damen"))
IO.puts("damen key: #{damen.key}")
IO.puts("damen chars: #{length(damen.characters)}")
IO.puts("damen item_instances: #{length(damen.item_instances)}")

Enum.each(damen.item_instances, fn inst ->
  IO.puts("  damen item: #{inst.item_id} (#{inst.id})")
end)
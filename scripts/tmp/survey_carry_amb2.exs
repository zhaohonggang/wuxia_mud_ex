alias Kantele.World.Loader
world = Loader.load()

zone_item_keys =
  Map.new(world.zones, fn zone ->
    keys = MapSet.new(Enum.map(zone.items || [], fn it -> it.id |> String.split(":", parts: 2) |> List.last() end))
    {zone.id, keys}
  end)

raw_refs =
  world.characters
  |> Enum.flat_map(fn char ->
    meta = char.meta
    carry = (is_struct(meta) and meta.carry) || (is_map(meta) and Map.get(meta, :carry)) || []

    carry
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&String.contains?(&1, ":"))
    |> Enum.map(fn ref ->
      zone = (is_struct(meta) and meta.zone_id) || (is_map(meta) and Map.get(meta, :zone_id)) || "?"
      {zone, char.name, ref}
    end)
  end)

multi_keys = ["armor1","beixin","bi","blade1","bluecloth","cheng_cloth","cloth1","cloth2","cloth4","fuchen","greenrobe","greyrobe","hat","necklace","pink_cloth","shoes","staff","stick","tiejiang","xuan_cloth","yayifu","ycloth"]

IO.puts("-- ambiguous keys: refs per key (zone:name pairs, unique) --")
Enum.each(multi_keys, fn key ->
  refs = Enum.filter(raw_refs, fn {_, _, ref} -> ref == "items.#{key}.id" end)
  uniq_zones = refs |> Enum.map(fn {z, _, _} -> z end) |> Enum.uniq() |> Enum.sort()
  defining = Enum.filter(zone_item_keys, fn {zid, ks} -> MapSet.member?(ks, key) end) |> Enum.map(&elem(&1,0)) |> Enum.sort()
  IO.puts("#{key}: #{length(refs)} refs; user_zones=#{Enum.join(uniq_zones, ",")} ; defining=#{Enum.join(defining, ",")}")
end)

IO.puts("\n-- zhen / empty key detail --")
Enum.filter(raw_refs, fn {_,_,ref} -> ref == "items.zhen.id" or ref == "items..id" end)
|> Enum.each(fn {z,n,r} -> IO.puts("#{z}:#{n} -> #{r}") end)

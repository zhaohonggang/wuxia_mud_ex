# B3 verification: LPC `set("female_only", 1)` was backfilled into 24 `items`
# blocks across 7 zones. This probe confirms parse_item_meta picked the key up
# and that items without it default to false. Read-only; run in the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_item_female_only.exs

world = Kantele.World.Loader.load()
items = world.items

fo = fn it -> it.meta.female_only end
flagged = Enum.filter(items, &fo.(&1))

IO.puts("items total             : #{length(items)}")
IO.puts("items female_only=true  : #{length(flagged)}")
IO.puts("  ids                   : #{inspect(Enum.map(flagged, & &1.id))}")

if flagged != [] do
  f = hd(flagged)

  IO.puts(
    "  sample                : #{f.id} name=#{f.name} unit=#{inspect(f.meta.unit)} armor=#{inspect(f.meta.armor)}"
  )
end

# guard: a weapon that also carries female_only must keep its weapon bitmask
mixed =
  Enum.filter(flagged, fn it -> it.meta.flag && it.meta.flag > 1 end)

IO.puts("flagged with flag>1     : #{length(mixed)} (must stay 0/1 bitmask-safe)")
IO.puts("flag values on flagged  : #{inspect(Enum.map(flagged, & &1.meta.flag) |> Enum.uniq())}")

case flagged do
  [] -> IO.puts("RESULT                  : NOTHING LOADED (regression)")
  _ ->
    if length(flagged) == 24 do
      IO.puts("RESULT                  : OK (24 loaded)")
    else
      IO.puts("RESULT                  : MISMATCH expected 24, got #{length(flagged)}")
    end
end

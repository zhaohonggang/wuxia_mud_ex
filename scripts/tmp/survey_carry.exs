# UG-06 survey: carry 引用未解引用统计
# 用法: mix run --no-start scripts/tmp/survey_carry.exs
alias Kantele.World.Loader

world = Loader.load()

items = Map.new(world.items, fn item -> {item.id, true} end)

{anomalies, ok} =
  Enum.reduce(world.characters, {[], 0}, fn char, {acc, ok} ->
    meta = char.meta
    carry = (is_struct(meta) and meta.carry) || (is_map(meta) and Map.get(meta, :carry)) || []

    Enum.reduce(carry, {acc, ok}, fn entry, {acc, ok} ->
      cond do
        is_binary(entry) and String.contains?(entry, ":") ->
          if Map.has_key?(items, entry) do
            {acc, ok + 1}
          else
            {[{char.id, entry, :missing_item} | acc], ok}
          end

        is_binary(entry) ->
          zone = (is_struct(meta) and meta.zone_id) || (is_map(meta) and Map.get(meta, :zone_id)) || "?"
          name = char.name
          {[{{zone, name}, entry, :raw_ref} | acc], ok}

        true ->
          {[{char.id, inspect(entry), :other} | acc], ok}
      end
    end)
  end)

raw = Enum.filter(anomalies, fn {_, _, k} -> k == :raw_ref end)
missing_item = Enum.filter(anomalies, fn {_, _, k} -> k == :missing_item end)
other = Enum.filter(anomalies, fn {_, _, k} -> k == :other end)

IO.puts("== UG-06 carry survey ==")
IO.puts("characters: #{length(world.characters)}")
IO.puts("carry entries resolved + item exists: #{ok}")
IO.puts("raw unresolved refs: #{length(raw)}")
IO.puts("resolved but item missing from world.items: #{length(missing_item)}")
IO.puts("other: #{length(other)}")

IO.puts("\n-- raw refs: by ref value (count | zone:name) --")

raw
|> Enum.group_by(fn {_, ref, _} -> ref end)
|> Enum.sort()
|> Enum.each(fn {ref, entries} ->
  IO.puts("#{ref}  x#{length(entries)}  e.g. #{inspect(Enum.take(entries, 2))}")
end)

IO.puts("\n-- raw refs: by zone --")

raw
|> Enum.group_by(fn {{zone, _, _}, _, _} -> zone end)
|> Enum.sort()
|> Enum.each(fn {zone, entries} -> IO.puts("#{zone}  x#{length(entries)}") end)

IO.puts("\n-- resolved but missing item --")
Enum.each(Enum.sort(missing_item), fn {id, ref, _} -> IO.puts("#{id}  ->  #{ref}") end)
IO.puts("\n-- other --")
Enum.each(other, fn {id, ref, _} -> IO.puts("#{id}  ->  #{ref}") end)

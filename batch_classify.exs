#!/usr/bin/env elixir
# Usage: mix run batch_classify.exs <file_list>

file_list = List.first(System.argv())

files = File.read!(file_list) |> String.split("\n", trim: true)

results = Enum.map(files, fn f ->
  case Kantele.World.LPCConverter.convert_file(f) do
    {:ok, ucl} ->
      cond do
        String.contains?(ucl, "# Generic LPC file") -> {f, "GENERIC"}
        String.contains?(ucl, "rooms \"") -> {f, "ROOM"}
        String.contains?(ucl, "characters \"") -> {f, "NPC"}
        String.contains?(ucl, "items \"") -> {f, "ITEM"}
        String.contains?(ucl, "skills \"") -> {f, "SKILL"}
        true -> {f, "UNHANDLED"}
      end
    {:error, e} ->
      IO.puts("ERROR: #{f} - #{inspect(e)}")
      {f, "ERROR"}
  end
end)

counts = Enum.reduce(results, %{}, fn {_, r}, acc ->
  Map.update(acc, r, 1, &(&1 + 1))
end)

IO.puts("=== Classification Summary ===")
Enum.each(["ROOM", "NPC", "ITEM", "SKILL", "GENERIC", "ERROR", "UNHANDLED"], fn k ->
  IO.puts("#{k}: #{counts[k] || 0}")
end)
IO.puts("TOTAL: #{length(results)}")
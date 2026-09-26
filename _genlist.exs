alias Kantele.World.LPCConverter

base = "/corpus/d"
skip = MapSet.new(["minimal_world", "minimal_world_v2"])

files =
  Path.wildcard(Path.join(base, "**/*.c"))
  |> Enum.filter(fn p ->
    rel = Path.relative_to(p, base)
    !Enum.any?(skip, fn d -> String.starts_with?(rel, d <> "/") end)
  end)

generic =
  Enum.reduce(files, [], fn path, acc ->
    case LPCConverter.convert_file(path, base_path: Path.dirname(path), include_comments: false) do
      {:ok, ucl} ->
        if String.contains?(ucl, "rooms \"") or String.contains?(ucl, "characters \"") or
             String.contains?(ucl, "items \"") or String.contains?(ucl, "# Skill file:") do
          acc
        else
          [Path.relative_to(path, base) | acc]
        end

      {:error, _} ->
        acc
    end
  end)
  |> Enum.sort()

IO.puts("generic_count=#{length(generic)}")
Enum.each(generic, &IO.puts(&1))
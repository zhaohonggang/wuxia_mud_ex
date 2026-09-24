base = "test_minimal_world_v2_modified"
ucl = File.read!("data/world/test.ucl")
sources = Path.wildcard(Path.join(base, "**/*.c"))

unhandled_names =
  Regex.scan(~r/^\s*# UNHANDLED FUNCTION:\s*([a-zA-Z_]\w*)/m, ucl)
  |> Enum.map(fn [_, n] -> n end)
  |> MapSet.new()

find_matching_brace = fn content, start_index ->
  find_loop = fn find_loop, i, count ->
    if i > String.length(content) - 1 do
      nil
    else
      char = String.at(content, i)
      cond do
        char == "{" -> find_loop.(find_loop, i + 1, count + 1)
        char == "}" ->
          if count - 1 == 0 do
            String.slice(content, start_index + 1, i - start_index - 1)
          else
            find_loop.(find_loop, i + 1, count - 1)
          end
        true -> find_loop.(find_loop, i + 1, count)
      end
    end
  end
  find_loop.(find_loop, start_index + 1, 1)
end

strip_comments = fn src ->
  src
  |> String.replace(~r/\/\/[^\n]*/, " ")
  |> String.replace(~r/\/\*[\s\S]*?\*\//, " ")
end

sig = ~r/(?:int|string|void|mixed|mapping|object|protected)\s+(\w+)\s*\([^)]*\)\s*\n*\s*\{/

losses =
  Enum.reduce(sources, [], fn path, acc ->
    content = File.read!(path)

    function_bodies =
      Enum.reduce(Regex.scan(sig, content), {[], content}, fn [match, name], {list, leftover} ->
        [_, leftover2] = String.split(leftover, match, parts: 2)
        brace_pos = String.length(content) - String.length(leftover2) - 1
        body = find_matching_brace.(content, brace_pos)
        {[{name, body} | list], leftover2}
      end)
      |> elem(0)

    exempt_ranges =
      function_bodies
      |> Enum.reject(fn {_name, body} -> is_nil(body) end)
      |> Enum.filter(fn {name, _} -> MapSet.member?(unhandled_names, name) end)
      |> Enum.map(fn {_, body} -> body end)

    scrubbed =
      Enum.reduce(exempt_ranges, content, fn body, acc ->
        String.replace(acc, body, String.duplicate(" ", String.length(body)), global: false)
      end)
      |> strip_comments.()

    chunks =
      Regex.scan(~r/[^\x00-\x7F]+/, scrubbed)
      |> List.flatten()
      |> Enum.filter(fn c ->
        String.length(c) >= 2 and String.match?(c, ~r/[\x{4e00}-\x{9fff}]/u)
      end)

    missing = chunks |> Enum.reject(fn c -> String.contains?(ucl, c) end) |> Enum.uniq()

    if missing != [] do
      [{Path.relative_to(path, base), missing} | acc]
    else
      acc
    end
  end)

total = losses |> Enum.map(fn {_, ms} -> ms end) |> List.flatten()

IO.puts("sources=#{length(sources)}  files_with_loss=#{length(losses)}  lost_chunks=#{length(total)}  exempt_fns=#{MapSet.size(unhandled_names)}")

File.write!("loss_report.txt", Enum.map_join(Enum.sort(losses), "\n", fn {f, ms} ->
  "== #{f}\n" <> Enum.map_join(ms, "\n", &"    #{&1}")
end))

Enum.each(Enum.sort(losses), fn {file, ms} ->
  IO.puts("\n== #{file}")
  Enum.each(ms, &IO.puts("    #{&1}"))
end)
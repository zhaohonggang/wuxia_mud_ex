content = File.read!("lib/kantele/world/lpc_converter.ex")
["set_name", "set(\"title", "set(\"nickname", "set(\"name", "nickname", "extract_set_primitives", "extract_set_calls"] 
|> Enum.each(fn pat ->
  hits = Regex.scan(~r/.{0,40}#{Regex.escape(pat)}.{0,40}/, content) |> List.flatten()
  IO.puts("== #{pat}: #{length(hits)}")
  Enum.take(hits, 4) |> Enum.each(&IO.puts("   #{String.trim(&1)}"))
end)
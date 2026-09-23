content = File.read!("test_minimal_world_v2_modified/npc/xiaoer.c")

# Find tell_object calls
tell_calls = Regex.scan(~r/tell_object\s*\([^)]+\)/, content)
IO.puts("Found tell_object calls: #{length(tell_calls)}")

Enum.each(tell_calls, fn [call] ->
  IO.puts("CALL: #{call}")
  Regex.scan(~r/"((?:\\.|[^"\\])*)"/, call)
  |> Enum.each(fn [_, s] ->
    IO.puts("  STR: #{s}")
  end)
end)

# Also check command say
cmd_says = Regex.scan(~r/command\s*\(\s*["']say\s+([^"']+)["']\s*\)/, content)
IO.puts("\nFound command say: #{length(cmd_says)}")
Enum.each(cmd_says, fn [_, msg] -> IO.puts("  SAY: #{msg}") end)

# say()
says = Regex.scan(~r/say\s*\(\s*["']([^"']+)["']\s*\)/, content)
IO.puts("\nFound say(): #{length(says)}")
Enum.each(says, fn [_, msg] -> IO.puts("  SAY: #{msg}") end)
content = File.read!("data/world/global.ucl")
matches = Regex.scan(~r/"\\/, content)
Enum.each(matches, fn match ->
  full = Enum.at(match, 0)
  IO.puts("Match: #{inspect(full)}")
  pos = String.index(content, full)
  if pos do
    IO.puts("Pos #{pos}: #{String.slice(content, max(0, pos-20), 50)}")
  end
end)
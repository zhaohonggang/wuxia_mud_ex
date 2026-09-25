content = File.read!("data/world/global.ucl")
matches = Regex.scan(~r/"\\/, content)
Enum.each(matches, fn [full] ->
  pos = String.index(content, full)
  if pos do
    IO.puts("Pos #{pos}: #{String.slice(content, max(0, pos-30), 80)}")
  end
end)
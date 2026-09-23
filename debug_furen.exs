content = File.read!("data/world/test.ucl")

lines = String.split(content, "\n")
in_block = false
Enum.each(lines, fn line ->
  if String.contains?(line, "characters \"furen\"") do
    in_block = true
  end
  if in_block do
    IO.puts(line)
  end
  if in_block and String.trim(line) == "}" do
    in_block = false
  end
end)
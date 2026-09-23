content = File.read!("data/world/test.ucl")

try do
  parsed = Elias.parse(content)
  IO.puts("PARSE OK")
rescue
  e ->
    IO.puts("PARSE ERROR: #{Exception.message(e)}")
end
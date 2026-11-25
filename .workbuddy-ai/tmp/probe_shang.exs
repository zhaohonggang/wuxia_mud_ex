alias Kantele.World.Loader

world = Loader.load()

IO.puts("=== shang-area room occupants ===")
world.characters
|> Enum.filter(fn c -> String.starts_with?(c.room_id || "", "shaolin:shang") end)
|> Enum.sort_by(& &1.room_id)
|> Enum.each(fn c ->
  m = c.meta
  IO.puts("#{c.room_id}  name=#{c.name}  zone=#{m.zone_id}  teach=#{inspect(if m.teach, do: m.teach.family, else: nil)}  deny_all=#{inspect(if m.apprentice, do: m.apprentice.deny_all, else: nil)}  guarder=#{inspect(if m.guarder, do: true, else: false)}  coagents=#{inspect(m.coagents)}  rescue=#{inspect(if m.rescue, do: true, else: false)}  chat=#{m.chat_chance_combat}")
end)

IO.puts("\n=== rooms ===")
Enum.each(world.rooms, fn r ->
  if String.starts_with?(r.id, "shaolin:shang") do
    IO.puts("#{r.id} behavior=#{inspect(r.behavior)} cfg=#{inspect(r.behavior_config)}")
  end
end)

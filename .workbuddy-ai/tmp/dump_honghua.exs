alias Kantele.World.Loader

world = Loader.load()

chosen =
  Enum.filter(world.characters, fn c ->
    Enum.any?(c.meta.aliases || [], &String.starts_with?(&1, "honghua_")) or
      (c.meta.zone_id == "kaifeng" and c.name == "无尘道长")
  end)

chunks =
  Enum.map(chosen, fn c ->
    """
    === #{c.id} / #{c.name} ===
    apprentice: #{inspect(c.meta.apprentice, pretty: true, limit: :infinity)}
    inquiries: #{inspect(c.meta.inquiries, pretty: true, limit: :infinity)}
    inquiry_state: #{inspect(c.meta.inquiry_state, pretty: true, limit: :infinity)}
    chat: #{inspect({c.meta.chat_chance_combat, c.meta.chat_msg_combat}, pretty: true, limit: :infinity)}
    """
  end)

File.write!(".workbuddy-ai/tmp/honghua_dump.txt", Enum.join(chunks, "\n"))

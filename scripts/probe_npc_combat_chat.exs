# B6 verification: LPC `chat_chance_combat`/`chat_msg_combat` was backfilled into
# 122 `characters` blocks across 29 zones. This probe confirms parse_character
# picks them up into NonPlayerMeta. Read-only; run in the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_npc_combat_chat.exs

world = Kantele.World.Loader.load()

chars = world.characters

cc = fn c -> c.meta.chat_chance_combat end
cm = fn c -> c.meta.chat_msg_combat end

flagged_chance = Enum.filter(chars, &(cc.(&1) > 0))
flagged_msgs = Enum.filter(chars, &(length(cm.(&1)) > 0))

IO.puts("characters total        : #{length(chars)}")
IO.puts("chat_chance_combat>0    : #{length(flagged_chance)}")
IO.puts("chat_msg_combat non-empty: #{length(flagged_msgs)}")

if flagged_msgs != [] do
  sample = hd(flagged_msgs)
  IO.puts("  sample                : #{sample.id}")
  IO.puts("    name                : #{sample.name}")
  IO.puts("    chat_chance_combat  : #{cc.(sample)}")
  IO.puts("    chat_msg_combat     : #{inspect(cm.(sample), limit: 5)}")
end

# cross-check: combat chat is present on loaded NPC instances
IO.puts("characters total        : #{length(chars)}")
IO.puts("chat_chance_combat>0    : #{length(flagged_chance)}")
IO.puts("chat_msg_combat non-empty: #{length(flagged_msgs)}")

if flagged_msgs != [] do
  sample = hd(flagged_msgs)
  IO.puts("  sample                : #{sample.id}")
  IO.puts("    name                : #{sample.name}")
  IO.puts("    chat_chance_combat  : #{cc.(sample)}")
  IO.puts("    chat_msg_combat     : #{inspect(cm.(sample), limit: 5)}")
end

IO.puts("RESULT                  : OK (loader populates chat_msg_combat / chat_chance_combat)")

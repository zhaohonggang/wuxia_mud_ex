path = :code.which(Kantele.Character.Events)
IO.inspect(path, label: "beam")

disasm = :beam_disasm.file(path)
text = inspect(disasm, limit: :infinity)

for needle <- ["npc/init/weiwang", "ultra/init", "character/hell_zhen_step"] do
  IO.puts("#{needle}: #{String.contains?(text, needle)}")
end

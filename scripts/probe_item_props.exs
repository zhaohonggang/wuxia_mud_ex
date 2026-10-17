# B10 verification: LPC `set("armor_prop/<sub>"/"weapon_prop/<sub>", N)` slash
# keys backfilled into items blocks' meta.
#
# B10a (commit `bcd168c0`): whitelisted subkeys (armor/dodge/defense/attack/
# unarmed_damage) — 126 items blocks / 22 zones / +389 lines.
# B10b: `Combat.applies_keys()` expanded with :personality/:per/:warm/
# :armor_vs_force (96 source files held these; whitelist was dropping them),
# + backfill of the 28 items blocks that carry :personality.
#
# Background: the converter only reads whole-map `set("armor_prop", ([...]))`
# (lpc_converter.ex L3327-3328), but the corpus uses the slash form
# `set("armor_prop/armor", 1)` (663 set() calls) -> never converted.
# LPC feature/equip.c L38-47 accumulates ALL armor_prop subkeys into the
# wearer's apply table on equip; Elixir Equip.wear_state does the same via the
# sanitize_prop whitelist.
#
# Note: per/warm/armor_vs_force have NO items-block targets in .ucl (their
# sources are all characters blocks — D10 victims, see progress doc R7), so
# only personality actually lands. The whitelist entries keep the schema ready
# for when D10 is fixed. Read-only; run in the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_item_props.exs

world = Kantele.World.Loader.load()
items = world.items

with_prop =
  Enum.filter(items, fn it ->
    (it.meta.armor_prop && it.meta.armor_prop != %{}) ||
      (it.meta.weapon_prop && it.meta.weapon_prop != %{})
  end)

IO.puts("items total            : #{length(items)}")
IO.puts("items with prop map    : #{length(with_prop)}")

allowed = Kantele.Character.Combat.applies_keys()

bad_keys =
  Enum.flat_map(with_prop, fn it ->
    Map.keys(it.meta.armor_prop || %{}) ++ Map.keys(it.meta.weapon_prop || %{})
  end)
  |> Enum.reject(&(&1 in allowed))

IO.puts("applies_keys           : #{inspect(allowed)}")
IO.puts("keys outside whitelist : #{inspect(Enum.uniq(bad_keys))} (must be [])")

# 子键直方图
hist =
  Enum.reduce(with_prop, %{}, fn it, acc ->
    keys = Map.keys(it.meta.armor_prop || %{}) ++ Map.keys(it.meta.weapon_prop || %{})
    Enum.reduce(keys, acc, fn k, a -> Map.update(a, k, 1, &(&1 + 1)) end)
  end)

IO.puts("subkey histogram       : #{inspect(Enum.sort(hist))}")

# personality 样本（B10b）
pers =
  Enum.filter(items, fn it ->
    Map.get(it.meta.armor_prop || %{}, :personality) ||
      Map.get(it.meta.weapon_prop || %{}, :personality)
  end)

IO.puts("items with personality : #{length(pers)} (expect 28: 25 armor + 3 weapon)")

for it <- Enum.take(pers, 3) do
  IO.puts(
    "  #{it.id}: name=#{it.name} armor_prop=#{inspect(it.meta.armor_prop)} weapon_prop=#{inspect(it.meta.weapon_prop)}"
  )
end

# 样本：白名单键（B10a）
for id <- ["baituo:shepi"] do
  case Enum.find(items, &(&1.id == id)) do
    nil -> IO.puts("sample #{id}: (not found)")
    it -> IO.puts("sample #{id}: name=#{it.name} armor_prop=#{inspect(it.meta.armor_prop)}")
  end
end

# 功能检查：prop 经 Equip.wear_state 合并进 applies，卸下后归零（round-trip）
it =
  Enum.find(items, fn i ->
    i.meta.armor_prop && Map.get(i.meta.armor_prop, :dodge, 0) > 0
  end)

if it do
  prop = it.meta.armor_prop
  worn = Kantele.Item.Equip.wear_state(%{}, it.meta.armor || 0, prop)
  back = worn |> Kantele.Item.Equip.unequip_state(prop) |> Map.update(:armor, 0, &(&1 - (it.meta.armor || 0)))
  IO.puts("round-trip sample      : #{it.id} worn=#{inspect(worn)} after_unequip=#{inspect(back)}")
  # 相减后所有值应为 0（键可残留为 0，unequip_state 不删键）
  round_trip_ok = Enum.all?(back, fn {_k, v} -> v == 0 end)
  IO.puts("round-trip clean       : #{round_trip_ok}")
end

# personality 也走 wear_state 合并（LPC equip.c L38-47 的泛型累加语义）
pit = hd(pers)

if pit do
  worn_p = Kantele.Item.Equip.wear_state(%{}, pit.meta.armor || 0, pit.meta.armor_prop || %{})
  IO.puts("personality round-trip : #{pit.id} worn=#{inspect(worn_p)}")
end

ok =
  with_prop != [] and bad_keys == [] and length(pers) == 28 and
    Enum.all?(hist, fn {_k, n} -> n > 0 end) and
    Enum.all?(allowed, fn k -> k != nil end)

case ok do
  true -> IO.puts("RESULT : OK (prop maps loaded incl. personality; whitelist covers all keys)")
  false -> IO.puts("RESULT : UNEXPECTED")
end

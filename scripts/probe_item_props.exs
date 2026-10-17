# B10a verification: LPC `set("armor_prop/<sub>", N)` slash keys backfilled into
# 126 `items` blocks across 22 zones (whitelisted subkeys: armor/dodge/defense/
# attack/unarmed_damage). Read-only; run in the container:
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_item_props.exs
#
# Background: the converter only reads whole-map `set("armor_prop", ([...]))`
# (lpc_converter.ex L3327-3328), but the corpus uses the slash form
# `set("armor_prop/armor", 1)` (663 set() calls) -> never converted. These are
# the whitelisted subkeys: they now flow through the existing consumer pipeline
# (Item.Meta.sanitize_prop keeps @applies_keys keys; Equip.wear_state merges
# them into applies, matching LPC feature/equip.c L38-47).

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
    (it.meta.armor_prop || %{}) |> Map.keys() |> Kernel.++(Map.keys(it.meta.weapon_prop || %{}))
  end)
  |> Enum.reject(&(&1 in allowed))

IO.puts("keys outside whitelist : #{inspect(Enum.uniq(bad_keys))} (must be [])")

# 子键直方图
hist =
  Enum.reduce(with_prop, %{}, fn it, acc ->
    keys = Map.keys(it.meta.armor_prop || %{}) ++ Map.keys(it.meta.weapon_prop || %{})
    Enum.reduce(keys, acc, fn k, a -> Map.update(a, k, 1, &(&1 + 1)) end)
  end)

IO.puts("subkey histogram       : #{inspect(Enum.sort(hist))}")

# 样本：city:maozi（帽子 dodge=5）、baituo:shepi（豹皮 armor=10）
for id <- ["city:maozi", "baituo:shepi", "shaolin:jiasha"] do
  case Enum.find(items, &(&1.id == id)) do
    nil -> IO.puts("sample #{id}: (not found)")
    it ->
      IO.puts(
        "sample #{id}: name=#{it.name} armor_prop=#{inspect(it.meta.armor_prop)} weapon_prop=#{inspect(it.meta.weapon_prop)}"
      )
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

ok = with_prop != [] and bad_keys == [] and Enum.all?(hist, fn {_k, n} -> n > 0 end)

case ok do
  true -> IO.puts("RESULT : OK (whitelisted prop maps loaded, keys in whitelist)")
  false -> IO.puts("RESULT : UNEXPECTED")
end

# B9 验证：Item.Meta.can_make/not_make/power_point/item_origin 已加字段，
# loader 从 items 块内部的 meta 块读取。
# 数据已回填：3 个区 / 14 个 items 块 / +49 行。
# Read-only; 容器内运行：
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_item_craft_keys.exs

world = Kantele.World.Loader.load()

items = world.items

IO.puts("items total            : #{length(items)}")

cm_items = Enum.filter(items, &(not is_nil(&1.meta.can_make)))
nm_items = Enum.filter(items, &(not is_nil(&1.meta.not_make)))
pp_items = Enum.filter(items, &(not is_nil(&1.meta.power_point)))
io_items = Enum.filter(items, &(not is_nil(&1.meta.item_origin)))

IO.puts("can_make   set       : #{length(cm_items)}")
IO.puts("not_make   set       : #{length(nm_items)}")
IO.puts("power_point set      : #{length(pp_items)}")
IO.puts("item_origin set      : #{length(io_items)}")

if cm_items != [] do
  s = hd(cm_items)
  IO.puts("  can_make  sample   : #{s.id} name=#{s.name} can_make=#{inspect(s.meta.can_make)}")
end

if nm_items != [] do
  s = hd(nm_items)
  IO.puts("  not_make  sample   : #{s.id} name=#{s.name} not_make=#{inspect(s.meta.not_make)}")
end

if pp_items != [] do
  s = hd(pp_items)
  IO.puts("  power_point sample : #{s.id} name=#{s.name} power_point=#{inspect(s.meta.power_point)}")
end

if io_items != [] do
  s = hd(io_items)
  IO.puts("  item_origin sample : #{s.id} name=#{s.name} item_origin=#{inspect(s.meta.item_origin)}")
end

cm_list_ok = Enum.all?(cm_items, &(is_list(&1.meta.can_make)))
nm_list_ok = Enum.all?(nm_items, &(is_list(&1.meta.not_make)))
pp_int_ok  = Enum.all?(pp_items,  &(is_integer(&1.meta.power_point)))
io_int_ok  = Enum.all?(io_items,  &(is_integer(&1.meta.item_origin)))

IO.puts("can_make  all list   : #{cm_list_ok}")
IO.puts("not_make  all list   : #{nm_list_ok}")
IO.puts("power_point all int  : #{pp_int_ok}")
IO.puts("item_origin all int  : #{io_int_ok}")

case {length(cm_items) > 0, length(nm_items) > 0,
      length(pp_items) > 0, length(io_items) > 0,
      cm_list_ok and nm_list_ok and pp_int_ok and io_int_ok} do
  {true, true, true, true, true} ->
    IO.puts("RESULT : OK (Item.Meta.craft 4 字段已加，loader 读取正常，类型正确)")
  _ ->
    IO.puts("RESULT : UNEXPECTED")
end

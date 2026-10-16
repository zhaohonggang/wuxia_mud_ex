# B8 验证：Item.Meta.max_liquid 已加字段，loader 从 items 块顶层读取。
# 数据已回填：30 个区 / 96 个 items 块 / +96 行。
# Read-only; 容器内运行：
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_item_max_liquid.exs

world = Kantele.World.Loader.load()

items = world.items

IO.puts("items total : #{length(items)}")

# 统计 max_liquid 非 nil 的物品数，并取样
with_liquid = Enum.filter(items, &(not is_nil(&1.meta.max_liquid)))
IO.puts("max_liquid set : #{length(with_liquid)}")

if with_liquid != [] do
  sample = hd(with_liquid)
  IO.puts("  sample id   : #{sample.id}")
  IO.puts("  sample name : #{sample.name}")
  IO.puts("  max_liquid  : #{sample.meta.max_liquid}")
end

# 断言：样本值应等于 LPC 里的 set("max_liquid", N)
# 这里只做结构性断言：非 nil 的值应都是整数
all_int = Enum.all?(with_liquid, &(is_integer(&1.meta.max_liquid)))
IO.puts("all max_liquid values are integer : #{all_int}")

case {length(with_liquid) > 0, all_int} do
  {true, true} ->
    IO.puts("RESULT : OK (Item.Meta.max_liquid 字段已加，loader 读取正常，值为整数)")
  _ ->
    IO.puts("RESULT : UNEXPECTED")
end

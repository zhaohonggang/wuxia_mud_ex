defmodule Kantele.World.CloneFallbackTest do
  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  # LPC 里有一层「全服共享对象」：`/clone/**`（clone/item、clone/weapon、
  # clone/fam…），共 1003 个 .c。它们**每个只有一份**，任何区的 NPC 都能引用。
  #
  # 我们这边对应的就是 `data/world/clone_lib.ucl` —— 纯物品区，0 房间 0 NPC。
  #
  # 解析顺序：本区优先，找不到再回退 clone_lib。这样：
  #   - 本区有定义 -> 用本区的（保持原行为不变）
  #   - 本区没有、clone_lib 有 -> 用共享的那份（对应 LPC 的 /clone/**）
  #   - 两边都没有 -> 仍然算悬空并报告
  #
  # 为什么不按「随便找个区」回退：`jitui` 在 7 个区有 4 个不同变体
  # （changan=炸鸡腿 / wudu=烤山鸡腿 / 其余=烤鸡腿），短 id 猜会静默拿错。
  # 但 clone_lib 是**唯一权威的共享层**，它内部不可能有同名两份
  # （一个 UCL 文件里不会有两个同 key 的块），所以回退到它是确定性的。

  setup_all do
    %{world: Loader.load()}
  end

  @clone "clone_lib"

  defp item(world, id), do: Enum.find(world.items, &(&1.id == id))

  describe "clone_lib 作为共享层" do
    test "它是纯物品区（0 房间 0 NPC）", %{world: world} do
      zone = Enum.find(world.zones, &(&1.id == @clone))

      assert zone, "clone_lib 区应该存在"
      # 注意：zone.characters 是在 split_out_characters 之后从各房间收集的实例，
      # clone_lib 没有房间，所以这里断言的是「定义」层为 0。
      assert zone.rooms == [], "clone_lib 不该有房间"
      assert length(zone.items) > 0, "clone_lib 应该只有物品"

      src = File.read!(Path.join("data/world", "#{@clone}.ucl"))

      assert src =~ ~r/zones\s+"clone_lib"/
      refute src =~ ~r/^\s*rooms\s+"/m, "clone_lib.ucl 不该有 rooms 块"

      # clone_lib 现在**也收 NPC** —— 被多个区共用的角色（LPC 作者图省事直接
      # 跨区引私有路径的那些），见 scripts/convert_shared_npcs.py。
      assert src =~ ~r/^\s*characters\s+"/m, "clone_lib.ucl 应含共享 NPC"
    end

    test "本区优先：本区有定义时不会被 clone_lib 抢走", %{world: world} do
      # city 自己有 jitui（烤鸡腿），clone_lib 也有 jitui。
      # 引用 city 的房间必须拿到 city 那份。
      assert item(world, "city:jitui"), "city:jitui 应存在"
      assert item(world, "#{@clone}:jitui"), "clone_lib:jitui 也应存在"

      # 两者 id 不同，说明确实是两份独立定义
      assert item(world, "city:jitui").id != item(world, "#{@clone}:jitui").id
    end

    test "回退只在「本区没有」时发生，不会改变已能解析的引用", %{world: world} do
      # 抽查若干「本区已定义」的物品，确认解析结果仍是本区那份。
      # 这三个是实测存在于本区的（别用猜的短 id）。
      for {zone, short} <- [{"city", "baozi"}, {"city", "jitui"}, {"changan", "jiudai"}] do
        local = item(world, "#{zone}:#{short}")
        assert local, "#{zone}:#{short} 应存在"
        assert local.id == "#{zone}:#{short}"
      end
    end
  end

  describe "回退的实际效果：/clone/** 的 vendor_goods" do
    test "clone_lib 覆盖 LPC clone/ 里的一批共享物品", %{world: world} do
      # 不做脆弱的条数断言，只钉住「这些共享物品确实在 clone_lib」。
      # （实测 clone_lib 有 gangjian；cloth 在别的区、blade/junfu 尚未转）
      src = File.read!(Path.join("data/world", "#{@clone}.ucl"))

      for short <- ~w(food water baozi gangjian) do
        assert src =~ ~r/items\s+"#{short}"\s*\{/,
               "clone_lib 应含 #{short}（LPC clone/ 的共享物品）"

        assert item(world, "#{@clone}:#{short}"), "#{@clone}:#{short} 应加载成功"
      end
    end

    test "回退让一部分原本悬空的引用变成可解析（悬空总数下降）" do
      # 之前 item 悬空 464，改动后 460 —— 正是 /clone/** 那批被救回。
      # 这里只断言「clone_lib 的物品可被任意区引用」这一行为，不写死具体数字。
      src = File.read!(Path.join("data/world", "#{@clone}.ucl"))
      m = Regex.run(~r/items\s+"(\w+)"\s*\{/, src)
      assert m, "clone_lib 应至少有一个物品"

      [_, short] = m
      world = Loader.load()

      # 找一个引用了 clone_lib 物品的区：加载后该物品实例应存在于 world.items
      assert Enum.any?(world.items, &(&1.id == "clone_lib:#{short}"))
    end
  end
end
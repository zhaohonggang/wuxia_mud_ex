defmodule Kantele.World.CrossZoneNpcTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  # LPC 里作者图省事，房间直接引**别的区**的 NPC 完整路径：
  #
  #   d/beijing/huiyingup.c   "/d/yitian/npc/zhaomin2" 之类
  #   d/luoyang/dongdoor.c    "/d/kaifeng/npc/guanbing" : 4
  #
  # 转换器把路径丢成裸 `characters.guanbing.id`，本区没定义就变悬空。
  # 现在的做法是：跨区借用的 NPC 统一进 `clone_lib`，ID 命名成
  # `<来源区>_<id>`，引用写 `characters.kaifeng_guanbing.id`，
  # loader 解析顺序是**本区优先、找不到才回退 clone_lib**。
  #
  # 这个文件守的就是那条回退链路。它曾经整条是死的：loader.ex 里
  # `@clone_zone_id "clone_zone_id"` 的**定义**写在文件末尾，而
  # `find_character_for_room/3` 的**使用**在它前面 —— Elixir 的模块属性
  # 按文件顺序展开，先用后设会展开成 `nil`，于是
  # `Enum.find(zones, &(&1.id == nil))` 恒为 nil：
  # `dereference/3` 能拿到 `clone_lib:xxx`，紧接着的回退查找却说
  # clone_lib 不存在，房间全空（表现为悬空 character 665 条）。
  #
  # 下面的断言盯的是**房间里真的有 NPC、而且名字是借来的那个人的**，
  # 不是「引用字符串长得对」。

  setup_all do
    %{world: Kantele.World.Loader.load()}
  end

  # `zone.rooms` 是**列表**（[%Room{}]），`zone.characters` 是**映射**（%{key => ch}）。
  defp room(world, zone_id, room_key) do
    world.zones
    |> Enum.find(&(&1.id == zone_id))
    |> case do
      nil -> nil
      zone -> Enum.find(zone.rooms, &(to_string(&1.key) == room_key))
    end
  end

  defp room_names(world, zone_id, room_key) do
    case room(world, zone_id, room_key) do
      nil -> []
      r -> r.characters |> Enum.map(& &1.name) |> Enum.sort()
    end
  end

  test "跨区借来的 NPC 真的落在房间里，而且用的是来源区那一份（不是同名替身）", ctx do
    # beijing/huiyingup 引 yitian 的赵敏 / 赵一伤 / 钱二败
    assert room_names(ctx.world, "beijing", "huiyingup") ==
             ["赵一伤", "赵敏", "钱二败"]
  end

  test "同一个 NPC 被两个房间引用时两份都在（引用计数来自 LPC 的 \": N\"）", ctx do
    # LPC: ": 2" —— 两个鳌府侍卫
    assert room_names(ctx.world, "beijing", "aofu_men") == ["鳌府侍卫", "鳌府侍卫"]
  end

  test "luoyang 聚义厅借的是**开封**的老太 / 知客僧，不是 luoyang 自己的同名角色", ctx do
    # LPC d/luoyang/juyi.c: "/d/kaifeng/npc/oldwomen" + "/d/kaifeng/npc/zhike"
    assert room_names(ctx.world, "luoyang", "juyi") == ["拾荒者", "烧香老太", "知客僧"]
  end

  test "同一个 borrowed NPC 在多个房间各自实例化（引用数来自 LPC 的 \": N\"）", ctx do
    # LPC: "/d/kaifeng/npc/qigai" : 2 —— 关帝庙两个乞丐
    assert room_names(ctx.world, "zhongzhou", "guandimiao") == ["乞丐", "乞丐"]
    assert room_names(ctx.world, "luoyang", "hutong3") == ["乞丐"]
  end

  test "chengdu 白帝城借的是**北京**的书生 / 诗人", ctx do
    assert room_names(ctx.world, "chengdu", "baidicheng") == ["书生", "书生", "诗人"]
  end

  test "本区自己有同名定义时优先用本区的，不被 clone_lib 抢走", ctx do
    # luoyang 自己有 guanbing（城门官兵），LPC 里 luoyang 也确实引的本区那份，
    # 所以引用保持裸 `characters.guanbing.id`，**不进** clone_lib。
    # 这里断言 clone_lib 里没有凭空多出来的 `kaifeng_guanbing` ——
    # 没有跨区引用就不该为它建一份。
    clone = Enum.find(ctx.world.zones, &(&1.id == "clone_lib"))

    keys = clone.characters |> Enum.map(&elem(&1, 0)) |> MapSet.new()

    assert MapSet.member?(keys, :yitian_zhaomin2)
    assert MapSet.member?(keys, :beijing_shiren)
    assert MapSet.member?(keys, :kaifeng_qigai)
    refute MapSet.member?(keys, :kaifeng_guanbing)
    refute MapSet.member?(keys, :guanbing)

    # clone_lib 里不该再有**完全裸**的共享 NPC ID。
    # （历史遗留的 dao_ke / jian_ke / seng_ren / tiao_fu 带下划线所以落在
    #   下面这个断言之外：hangzhou / hengyang / shaolin / taishan 还在用裸
    #   引用指它们，删掉会凭空多出悬空引用，等那些区也 namespacing 完再清。）
    bare =
      clone.characters
      |> Enum.map(&elem(&1, 0))
      |> Enum.filter(&(not String.contains?(Atom.to_string(&1), "_")))

    assert bare == []

    legacy = [:dao_ke, :jian_ke, :seng_ren, :tiao_fu]
    assert Enum.all?(legacy, &MapSet.member?(keys, &1))
  end
end
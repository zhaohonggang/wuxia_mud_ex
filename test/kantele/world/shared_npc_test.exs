defmodule Kantele.World.SharedNpcTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  # LPC 里这些 NPC 是**跨区共享**的：房间用完整路径引用同一个人物，
  # 而转换器把路径丢成了裸 id，于是「本区没定义」的区全成了空房。
  #
  # LPC 原文证据（用 `Generated from` 注释把房间映射回源文件后读 set("objects")）：
  #
  #   d/lanzhou/ximen.c   "/d/city/npc/bing"      : 4,   <- 兰州城门用的是**开封**的官兵
  #   d/suzhou/beimen.c   "/d/city/npc/bing"      : 2,
  #   d/zhongzhou/chenglou.c "/d/kaifeng/npc/guanbing" : 4,
  #   d/beijing/majiu.c   "/clone/npc/mafu"       : 1,
  #   d/*/…               "/clone/npc/walker"     : 1,
  #
  # 所以补的不是「随便找个同名 NPC 复制」，而是把**那个** NPC 复制到引用它的区。

  @mafu_zones ~w(beijing changan chengdu city dali emei foshan fuzhou guanwai hangzhou
                 hengyang huanghe jingzhou kaifeng kunming lanzhou lingzhou luoyang
                 quanzhen quanzhou shaolin suzhou xiangyang xiyu zhongzhou)

  # 这 10 个区的 bing 全部指向 LPC 的 /d/city/npc/bing
  @bing_zones ~w(chengdu fuzhou guanwai huanghe kunlun kunming lanzhou quanzhou shaolin suzhou)

  @guanbing_zones ~w(zhongzhou)

  setup_all do
    %{world: Kantele.World.Loader.load()}
  end

  defp character_names(world, zone) do
    world.characters
    |> Enum.filter(&(&1.meta.zone_id == zone))
    |> Enum.map(& &1.name)
  end

  # `zone.characters` 是 `%{id => %Character{}}` 映射，
  # 但 `zone.items` 是 **列表**（[%Item{}]），两种形状都要处理。
  defp zone_defined?(world, zone, kind, id) do
    Enum.any?(world.zones, fn z ->
      if z.id != zone do
        false
      else
        case Map.get(z, kind) do
          m when is_map(m) -> Map.has_key?(m, String.to_atom(id))
          l when is_list(l) -> Enum.any?(l, &(&1.id == "#{zone}:#{id}"))
          _ -> false
        end
      end
    end)
  end

  describe "mafu（/clone/npc/mafu）" do
    test "25 个引用它的区都有定义", %{world: world} do
      missing = Enum.reject(@mafu_zones, &zone_defined?(world, &1, :characters, "mafu"))

      assert missing == [], "这些区缺 characters \"mafu\": #{inspect(missing)}"
    end

    test "实际生成了 27 个马夫实例", %{world: world} do
      count =
        Enum.count(world.characters, fn c ->
          c.meta.zone_id in @mafu_zones and c.name == "马夫"
        end)

      assert count == 27, "应为 27（lpc 里 emei / quanzhou 各多一个），实际 #{count}"
    end

    test "马夫认得人、也接生意", %{world: world} do
      mafu =
        Enum.find(world.characters, fn c ->
          c.meta.zone_id == "suzhou" and c.name == "马夫"
        end)

      assert mafu, "suzhou:majiu 里应该有马夫"
      assert mafu.meta.combat_config.spawn_room_id == "suzhou:majiu"
      assert [greeting] = mafu.meta.greetings
      assert greeting =~ "打算去哪儿"
      assert Enum.any?(mafu.meta.accept, &(&1.kind == "money" and &1.accept))
    end
  end

  describe "bing（/d/city/npc/bing）" do
    test "10 个引用它的区都有定义", %{world: world} do
      missing = Enum.reject(@bing_zones, &zone_defined?(world, &1, :characters, "bing"))

      assert missing == [], "这些区缺 characters \"bing\": #{inspect(missing)}"
    end

    test "是「官兵」而不是大理国的「士兵」", %{world: world} do
      # dali 自己的 bing 是另一个 NPC（set_name("士兵", ...)，大理国禁卫军），
      # 不能拿它去填别的区。
      for zone <- @bing_zones do
        assert "官兵" in character_names(world, zone),
               "#{zone} 的 bing 应叫「官兵」"
      end
    end

    test "带着 LPC 里的 engage 台词", %{world: world} do
      bing =
        Enum.find(world.characters, fn c ->
          c.meta.zone_id == "lanzhou" and c.name == "官兵"
        end)

      assert bing, "兰州应该有官兵"
      assert bing.meta.stats.combat_exp == 10_000
      assert bing.meta.combat_config.attitude == "peaceful"
      assert bing.meta.engage.fight.accept == true
      assert bing.meta.engage.fight.msg =~ "今天算你倒霉"
    end

    test "兰州城门有 4 个官兵（LPC 里 \": 4\"）", %{world: world} do
      # d/lanzhou/ximen.c: "/d/city/npc/bing" : 4
      count = Enum.count(character_names(world, "lanzhou"), &(&1 == "官兵"))
      assert count == 16, "兰州全区官兵 16（4 个城门 x 4），实际 #{count}"
    end
  end

  describe "guanbing（/d/kaifeng/npc/guanbing）" do
    test "zhongzhou 有定义", %{world: world} do
      assert zone_defined?(world, "zhongzhou", :characters, "guanbing")
    end

    test "chenglou 的 16 个guanbing 真的生成了", %{world: world} do
      # LPC: d/zhongzhou/chenglou.c  "/d/kaifeng/npc/guanbing" : 4
      for zone <- @guanbing_zones do
        count = Enum.count(character_names(world, zone), &(&1 == "官兵"))
        assert count >= 16, "#{zone} 至少应有 16，实际 #{count}"
      end
    end
  end

  describe "walker（/clone/npc/walker）" do
    # LPC 里是 `NPC_D->generate_cn_name(this_object())`，名字运行时随机生成，
    # 转换器只能填占位符 `name = "NPC"`。这里按 LPC 的 long 描述取「拾荒者」，
    # 免得 35 个区的拾荒者全叫「NPC」。
    @walker_zones ~w(baituo beijing changan chengdu city dali foshan fuzhou guanwai gumu
                     hangzhou huashan jingzhou kaifeng kunming lanzhou lingjiu lingxiao
                     lingzhou luoyang mingjiao quanzhen quanzhou shaolin songshan suzhou
                     tulong village wudu xiakedao xiangyang xiyu xuedao xueshan zhongzhou)

    test "35 个引用它的区都有定义", %{world: world} do
      missing = Enum.reject(@walker_zones, &zone_defined?(world, &1, :characters, "walker"))

      assert missing == [], "这些区缺 characters \"walker\": #{inspect(missing)}"
    end

    test "生成了 139 个拾荒者", %{world: world} do
      count = Enum.count(world.characters, &(&1.name == "拾荒者"))

      assert count == 139,
             "应为 139（LPC 里 141 条引用，但其中 2 条其实是别的 NPC，见下），实际 #{count}"
    end

    test "属性与 LPC 一致", %{world: world} do
      w = Enum.find(world.characters, &(&1.meta.zone_id == "beijing" and &1.name == "拾荒者"))

      assert w, "北京应有拾荒者"
      # clone/npc/walker.c: str 35 / int 15 / con 19 / dex 17, attitude heroism
      assert w.meta.stats.str == 35
      assert w.meta.stats.int == 15
      assert w.meta.stats.con == 19
      assert w.meta.stats.dex == 17
      assert w.meta.combat_config.attitude == "heroism"
    end

    test "walker 定义里没有占位名 \"NPC\"", %{world: world} do
      # 只看定义块，不看运行时实例 —— 别区里本来就有个叫 "NPC" 的家伙
      # （名字确实是 "NPC"，跟 walker 无关），按实例筛会误报。
      for zone <- @walker_zones do
        z = Enum.find(world.zones, &(&1.id == zone))
        w = Map.fetch!(z.characters, :walker)

        assert w.name == "拾荒者",
               "#{zone} 的 walker 名字应是「拾荒者」，实际 #{inspect(w.name)}"
      end
    end
  end

  describe "转换器误命名的 2 处已修正" do
    # LPC 里这两个房间放的根本不是 walker，但 UCL 把 id 写成了
    # characters.walker.id —— 不修的话，补了 walker 之后它们会变成拾荒者。
    #
    #   d/dali/buxiongbu.c    objects: npc/bshangfan -> 台夷商贩
    #   d/foshan/street1.c    objects: npc/jiading   -> 家丁
    test "dali:buxiongbu 放的是台夷商贩", %{world: world} do
      assert zone_defined?(world, "dali", :characters, "bshangfan")

      shopkeepers =
        Enum.filter(world.characters, &(&1.meta.zone_id == "dali" and &1.name == "台夷商贩"))

      assert shopkeepers != [], "dali:buxiongbu 的台夷商贩应该存在"

      # LPC 里台夷商贩不止摆在 buxiongbu（还有 hexi 等），所以只要求
      # buxiongbu 里确实有一个，别把其它房间的也算进来。
      in_room =
        Enum.filter(shopkeepers, &(&1.meta.combat_config.spawn_room_id == "dali:buxiongbu"))

      assert in_room != [], "dali:buxiongbu 里应有台夷商贩，实际摆在 " <>
                             "#{inspect(Enum.map(shopkeepers, & &1.meta.combat_config.spawn_room_id))}"
    end

    test "foshan:street1 放的是家丁", %{world: world} do
      assert zone_defined?(world, "foshan", :characters, "jiading")

      servants =
        Enum.filter(world.characters, &(&1.meta.zone_id == "foshan" and &1.name == "家丁"))

      assert servants != [], "foshan:street1 的家丁应该存在"
    end

    test "这两个房间的引用已经指回正确的 id", %{world: world} do
      # 若引用还写着 characters.walker.id，这两个房间会同时出现两个 NPC，
      # 数量对不上（LPC 各只有 1 个）
      for {zone, room} <- [{"dali", "buxiongbu"}, {"foshan", "street1"}] do
        insts =
          Enum.filter(world.characters, &(&1.meta.combat_config.spawn_room_id == "#{zone}:#{room}"))

        assert length(insts) == 1,
               "#{zone}:#{room} 应恰好 1 个 NPC，实际 #{length(insts)}: " <>
                 "#{inspect(Enum.map(insts, & &1.name))}"
      end
    end
  end

  describe "carry 目前是死数据（已知缺口，与本次补齐无关）" do
    test "bing 的 carry 引用的 blade / junfu 已补进那些区，但运行时没穿上" do
      # 数据层面补齐了，好让 carry 里的 items.blade.id / items.junfu.id 不悬空；
      # 但 loader 根本不解析 `carry`，NonPlayerMeta 也没有这个字段，
      # 所以 NPC 出生时并不会真的拿到钢刀和军服。
      # 这里把现状钉住，等哪天真实现了 carry 再改。
      world = Kantele.World.Loader.load()

      for zone <- @bing_zones do
        assert zone_defined?(world, zone, :items, "blade"),
               "#{zone} 应有 items \"blade\"（bing 的 carry 依赖）"

        assert zone_defined?(world, zone, :items, "junfu"),
               "#{zone} 应有 items \"junfu\"（bing 的 carry 依赖）"
      end

      bing = Enum.find(world.characters, &(&1.meta.zone_id == "lanzhou" and &1.name == "官兵"))

      assert bing.inventory == [],
             "carry 还没接上，所以背包是空的 —— 这条断言是为了让缺口显形"
    end
  end
end
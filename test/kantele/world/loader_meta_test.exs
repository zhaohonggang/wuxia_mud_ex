defmodule Kantele.World.LoaderMetaTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  test "食物物品解析 weight/unit/food 等通用字段" do
    world = Kantele.World.Loader.load()

    # 按 id 精确取，避免同名物品（如各区的「包子」）随转换集合变化而遮蔽
    baozi = Enum.find(world.items, &(&1.id == "liuxi:baozi"))
    assert baozi != nil
    assert baozi.meta.value == 15
    assert baozi.meta.weight == 80
    assert baozi.meta.unit == "个"
    assert baozi.meta.material == "food"
    assert baozi.meta.food == 20
    assert baozi.meta.book == nil
    assert baozi.meta.medicine == nil
  end

  test "秘籍物品解析 book 五元组" do
    world = Kantele.World.Loader.load()

    jianpu = Enum.find(world.items, &(&1.id == "liuxi:jianpu"))
    assert jianpu != nil
    assert jianpu.meta.weight == 50
    assert jianpu.meta.unit == "本"

    book = jianpu.meta.book
    assert %Kantele.World.Item.Meta.Book{} = book
    assert book.skill == "sword"
    assert book.min_skill == 0
    assert book.max_skill == 30
    assert book.exp_required == 0
    assert book.jing_cost == 20
    assert book.difficulty == 20
  end

  test "无 meta 块的旧字段物品不受影响" do
    world = Kantele.World.Loader.load()

    changjian = Enum.find(world.items, &(&1.id == "liuxi:changjian"))
    assert changjian.meta.damage == 22
    assert changjian.meta.skill_type == "sword"
    # 未配置的新字段保持默认空值
    assert changjian.meta.weight == nil
    assert changjian.meta.food == nil
  end

  # ---- b6/D3 装备多槽位字段 ----

  test "armor_type/weapon_prop/armor_prop 解析与归一化" do
    world = Kantele.World.Loader.load()

    changjian = Enum.find(world.items, &(&1.id == "liuxi:changjian"))
    assert changjian.meta.weapon_prop == %{attack: 3}
    assert changjian.meta.armor_type == nil

    # 按 id 精确取，不要用 name 模糊匹配：taohua 也有叫「布袍」的 bupao
    # （无 armor_type/armor_prop），模糊匹配会命中它并遮住 liuxi 这件，
    # 让本测试随已转换区域集合变化而flaky。
    bupao = Enum.find(world.items, &(&1.id == "liuxi:bupao"))
    assert bupao.meta.armor_type == "cloth"
    assert bupao.meta.armor_prop == %{defense: 4}

    douli = Enum.find(world.items, &(&1.id == "liuxi:douli"))
    assert douli.meta.armor_type == "head"
    assert douli.meta.armor_prop == %{defense: 2, dodge: -1}

    yaodai = Enum.find(world.items, &(&1.id == "liuxi:yaodai"))
    assert yaodai.meta.armor_type == "waist"
    assert yaodai.meta.armor_prop == %{dodge: 3}
  end

  test "铁铺房间摆放了斗笠与束腰带实例" do
    zone =
      world_zones()
      |> Enum.find(&(&1.id == "liuxi"))

    tiepupu = Enum.find(zone.rooms, &(&1.id == "liuxi:tiepupu"))
    instances = Map.get(tiepupu, :item_instances, [])
    item_ids = Enum.map(instances, & &1.item_id)

    assert "liuxi:douli" in item_ids
    assert "liuxi:yaodai" in item_ids
  end

  test "normalize_armor_type：body 别名、白名单外拒绝" do
    alias Kantele.World.Item.Meta

    assert Meta.normalize_armor_type("body") == "cloth"
    assert Meta.normalize_armor_type("HEAD") == "head"
    assert Meta.normalize_armor_type(" cloth ") == "cloth"
    assert Meta.normalize_armor_type("tail") == nil
    assert Meta.normalize_armor_type(42) == nil
    assert Meta.normalize_armor_type(nil) == nil
  end

  test "sanitize_prop：白名单过滤与非整数值丢弃" do
    alias Kantele.World.Item.Meta

    assert Meta.sanitize_prop(%{attack: 3, dodge: -1}) == %{attack: 3, dodge: -1}
    assert Meta.sanitize_prop(%{"parry" => 5}) == %{parry: 5}
    # 白名单外键（技能类加成）丢弃
    assert Meta.sanitize_prop(%{sword: 5, attack: 2}) == %{attack: 2}
    # 非整数值丢弃
    assert Meta.sanitize_prop(%{attack: "high"}) == nil
    assert Meta.sanitize_prop(%{}) == nil
    assert Meta.sanitize_prop(nil) == nil
  end

  test "镇广场摆放了新物品实例" do
    zone =
      world_zones()
      |> Enum.find(&(&1.id == "liuxi"))

    guangchang = Enum.find(zone.rooms, &(&1.id == "liuxi:guangchang"))
    instances = Map.get(guangchang, :item_instances, [])
    assert length(instances) == 2
  end

  # ---- init()/greeting()/accept_object()（converter 抽取 → meta 落位） ----

  test "xiaoer：init/greetings/accept 三块全量解析" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    xiaoer = Map.fetch!(test_zone.characters, :xiaoer).meta

    assert xiaoer.init.greet_delay == 1
    assert xiaoer.init.heartbeat == 0
    assert xiaoer.init.add_actions == ["drop", "exchange", "duihuan"]

    assert length(xiaoer.greetings) == 2
    assert Enum.all?(xiaoer.greetings, &String.contains?(&1, "{respect}"))

    assert Enum.any?(xiaoer.accept, &(&1.kind == "money" && &1.min == 1000 && &1.accept))
    assert Enum.any?(xiaoer.accept, &(&1.kind == "any" && &1.accept))

    # accept 台词池：any 规则 msg 为随机台词池（对应 LPC switch(random(N))）
    any_rule = Enum.find(xiaoer.accept, &(&1.kind == "any"))
    assert any_rule.msg == ["好！好！", "不需要的东西全给我！"]
    assert msg = Enum.find(xiaoer.accept, &(&1.kind == "money")).msg
    assert msg == ["小二一哈腰，说道：多谢您老，客官请上楼歇息。"]
  end

  test "furen：item_id/item_name 规则与 any 并存" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    furen = Map.fetch!(test_zone.characters, :furen).meta

    assert Enum.any?(furen.accept, &(&1.kind == "item_id" && &1.id == "wu zhi rong"))
    assert Enum.any?(furen.accept, &(&1.kind == "item_name" && &1.name == "明史辑略"))
    assert Enum.any?(furen.accept, &(&1.kind == "any" && &1.accept == true))
  end

  test "worker-liu：仅 init，greetings/accept 缺席" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    worker = Map.fetch!(test_zone.characters, :worker_liu).meta

    assert worker.init.heartbeat == 1
    assert worker.greetings == nil
    assert worker.accept == nil
  end

  test "普通 NPC（duke）：三块均缺席" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    duke = Map.fetch!(test_zone.characters, :duke).meta

    assert duke.init == nil
    assert duke.greetings == nil
    assert duke.accept == nil
  end

  test "menwei：guarder meta 解析（family + msgs）" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    menwei = Map.fetch!(test_zone.characters, :menwei)

    assert menwei.meta.guarder != nil
    assert menwei.meta.guarder.family == "白驼山庄"
    assert menwei.meta.guarder.msgs != %{}
    assert String.contains?(menwei.meta.guarder.msgs.refuse_other, "白驼山庄重地")
  end

  test "非守卫 NPC（xiaoer/furen/duke）guarder 为 nil" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))

    assert Map.fetch!(test_zone.characters, :xiaoer).meta.guarder == nil
    assert Map.fetch!(test_zone.characters, :furen).meta.guarder == nil
    assert Map.fetch!(test_zone.characters, :duke).meta.guarder == nil
  end

  test "xiaoer2：KNOWER+dealer 结构，goods 无果路径转注释不影响加载" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    xiaoer2 = Map.fetch!(test_zone.characters, :xiaoer2)

    assert xiaoer2.meta.init.add_actions == ["buy", "list"]
    assert length(xiaoer2.meta.greetings) == 2

    # test 区是旧转换器的测试夹具，不在 vendor 商品补齐范围内：
    # 它的 vendor_goods 仍以注释留存，goods 为 nil
    assert xiaoer2.meta.goods == nil
  end

  # ---- 商品引用解引用（同区 / 跨区 / 悬空） ----
  #
  # 注意：解引用发生在 Loader.parse_characters，结果只写进 world.characters
  # （房间里那份 Character 副本）；world.zones[].characters 里仍是未解引用的
  # 原始 meta。断言解引用结果必须从 world.characters 取。

  defp vendor(world, zone_id, name) do
    Enum.find(world.characters, &(&1.meta.zone_id == zone_id and &1.name == name))
  end

  test "跨区商品引用解引用成目标区物品 id" do
    world = Kantele.World.Loader.load()

    # 原 LPC changan/npc/liu.c 的 vendor_goods 写的是绝对路径
    # （/d/xiyu/obj/fire、/d/item/obj/chanhs），跨区售卖是原有语义
    liu = vendor(world, "changan", "刘老实")
    assert "xiyu:fire" in liu.meta.goods
    assert "item:chanhs" in liu.meta.goods

    # 原 LPC kaifeng/npc/hanzi.c 卖的是 /d/beijing/obj/luobo 等
    hanzi = vendor(world, "kaifeng", "菜贩子")
    assert "beijing:luobo" in hanzi.meta.goods
    assert "beijing:tudou" in hanzi.meta.goods
  end

  test "同区商品引用解引用成 <区>:<名>" do
    world = Kantele.World.Loader.load()

    # 原 LPC beijing/npc/caifan.c：vendor_goods 为本区 obj/luobo、obj/tudou 等
    caifan = vendor(world, "beijing", "菜贩子")
    assert "beijing:luobo" in caifan.meta.goods
    assert "beijing:tudou" in caifan.meta.goods

    # 同区引用必须原样保留顺序（vendor_list 按 goods 顺序列货）
    assert caifan.meta.goods == [
             "beijing:luobo",
             "beijing:huluobo",
             "beijing:baicai",
             "beijing:dacong",
             "beijing:tudou"
           ]
  end

  test "goods 不残留未解引用的跨区引用串" do
    world = Kantele.World.Loader.load()

    dangling =
      Enum.flat_map(world.characters, fn ch ->
        case ch.meta && ch.meta.goods do
          nil -> []
          goods -> Enum.filter(goods, &String.match?(&1, ~r/^[a-z0-9_]+\.items\./))
        end
      end)

    # 跨区引用（<区>.items.<名>.id）解不出 = loader 解引用坏了，必须为空。
    # 同区悬空（items.<名>.id）是「物品尚未建」的待补清单，随商品补齐逐步减少，
    # 不用在这里钉死数量。
    assert dangling == []
  end

  # ---- engage（accept_fight/hit/kill 抽取 → meta 落位） ----

  test "shouwei：engage 三键均拒绝、台词占位、继承回退注入" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    shouwei = Map.fetch!(test_zone.characters, :shouwei).meta

    assert shouwei.engage != nil
    assert shouwei.engage.fight.accept == false
    assert shouwei.engage.hit.accept == false
    assert shouwei.engage.kill.accept == false
    assert shouwei.engage.fight.msg == "{npc}吓了一跳，慌忙对{name}道：“小的不敢，小的不敢！”"
  end

  test "wudunru：fight 拒绝、hit/kill 接受并反杀（retaliate）" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    wudunru = Map.fetch!(test_zone.characters, :wudunru).meta

    assert wudunru.engage.fight.accept == false
    assert wudunru.engage.hit.accept == true
    assert wudunru.engage.hit.retaliate == true
    assert wudunru.engage.hit.spawn == []
    assert wudunru.engage.kill.accept == true
    assert wudunru.engage.kill.retaliate == true
  end

  test "jiang：accept_fight 接受，无台词无反杀" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    jiang = Map.fetch!(test_zone.characters, :jiang).meta

    assert jiang.engage.fight.accept == true
    assert jiang.engage.fight.msg == nil
    assert jiang.engage.fight.retaliate == false
  end

  test "huangyi：kill 拒绝但召唤保镖 spawn" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    huangyi = Map.fetch!(test_zone.characters, :huangyi).meta

    assert huangyi.engage.fight.accept == false
    assert huangyi.engage.kill.accept == false
    assert huangyi.engage.kill.retaliate == false
    assert huangyi.engage.kill.spawn == ["baobiao"]
  end

  test "无 accept_* 的 NPC（duke）engage 为 nil" do
    world = Kantele.World.Loader.load()
    test_zone = Enum.find(world.zones, &(&1.id == "test"))
    duke = Map.fetch!(test_zone.characters, :duke).meta

    assert duke.engage == nil
  end

  defp world_zones() do
    Kantele.World.Loader.load().zones
  end

  # ---- item_desc 墙牌/菜单 + valid_leave 出口阻挡（room 数据化） ----
  #
  # 全部按 `id`（含区名）定位，不按 `key`。房间 key 在全库大量重名（432 个 key 有
  # 多个属主：`majiu` 22 个区、`kedian` 19 个、`liandan_lin1` 同时属于 beijing 和
  # test），`Enum.find` 按 key 只会拿到迭代顺序里第一个，未必是想验的那个。

  test "bet 房间：item_desc 解析 paizi 规则板" do
    world = Kantele.World.Loader.load()
    bet = Enum.find(world.rooms, &(&1.id == "test:bet"))

    assert bet != nil
    assert Map.has_key?(bet.item_desc, "paizi")
    assert String.contains?(bet.item_desc["paizi"], "赌博规则")
    assert String.contains?(bet.item_desc["paizi"], "一赢三十六")
  end

  test "cave 房间：valid_leave 阻挡结构化为 exit_vetoes" do
    world = Kantele.World.Loader.load()
    cave = Enum.find(world.rooms, &(&1.id == "test:cave"))

    assert cave != nil
    assert cave.exit_vetoes == [
             %{
               direction: "in",
               condition: nil,
               message: "蟒蛇盘在岩洞口，将路封了个严实。",
               all_dirs: false
             }
           ]
  end

  test "kedian 房间：两条条件阻挡都被保留" do
    world = Kantele.World.Loader.load()
    kedian = Enum.find(world.rooms, &(&1.id == "test:kedian"))

    assert kedian != nil
    assert length(kedian.exit_vetoes) == 2
    assert Enum.any?(kedian.exit_vetoes, &(&1.direction == "up"))
    assert Enum.any?(kedian.exit_vetoes, &(&1.direction == "west"))
  end

  # Locate by `id`, never by `key`: room keys repeat across zones (there are 432
  # duplicated keys in the world - `majiu` in 22 zones, `chufang` in 20, `road2` in
  # 19, `liandan_lin1` in both beijing and test).  An `Enum.find` on `key` returns
  # whichever zone comes first in iteration order, which is how this test used to
  # assert against beijing:liandan_lin1 - a room that legitimately has four exits -
  # while claiming to check test:liandan_lin1's dangling ones.
  test "liandan_lin1 房间：宏继承合并属性生效（名称/描述），悬挂出口被丢弃" do
    world = Kantele.World.Loader.load()

    # beijing owns a room with the same key and it has all four exits wired up, so
    # the ambiguity is real rather than theoretical.
    assert Enum.any?(world.rooms, &(&1.id == "beijing:liandan_lin1"))

    room = Enum.find(world.rooms, &(&1.id == "test:liandan_lin1"))

    assert room != nil
    assert room.name == "城西后林"
    assert room.description =~ "这是一片茂密的树林"
    assert room.description =~ "遮蔽得暗然无光"

    # LPC 源码里的四个出口（south/north/east/west）目标房间在库中均不存在，loader 全部丢弃
    for dir <- ["south", "north", "east", "west"] do
      refute Enum.any?(room.exits, &(&1.exit_name == dir)),
             "悬挂出口 #{dir} 不应被保留"
    end

    # assign_room_coords.py 为孤儿房 liandan_lin 补了 room_exits 块，并用一条 down
    # 把它接到可达区域；liandan_lin 真实存在，所以这条出口现在会被 loader 保留。
    assert [%Kalevala.World.Exit{} = down] = room.exits
    assert down.exit_name == "down"
    assert down.end_room_id == "test:liandan_lin"
    assert down.id == "test:liandan_lin1:down"
  end

  test "liandan_lin 房间：父类（inherit ROOM）也正常加载" do
    world = Kantele.World.Loader.load()
    room = Enum.find(world.rooms, &(&1.id == "test:liandan_lin"))
    assert room != nil
  end
end

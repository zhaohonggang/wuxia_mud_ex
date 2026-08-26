defmodule Kantele.World.LoaderMetaTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  test "食物物品解析 weight/unit/food 等通用字段" do
    world = Kantele.World.Loader.load()

    baozi = Enum.find(world.items, &String.contains?(&1.name, "包子"))
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

    jianpu = Enum.find(world.items, &String.contains?(&1.name, "剑谱"))
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

    changjian = Enum.find(world.items, &String.contains?(&1.name, "长剑"))
    assert changjian.meta.damage == 22
    assert changjian.meta.skill_type == "sword"
    # 未配置的新字段保持默认空值
    assert changjian.meta.weight == nil
    assert changjian.meta.food == nil
  end

  # ---- b6/D3 装备多槽位字段 ----

  test "armor_type/weapon_prop/armor_prop 解析与归一化" do
    world = Kantele.World.Loader.load()

    changjian = Enum.find(world.items, &String.contains?(&1.name, "长剑"))
    assert changjian.meta.weapon_prop == %{attack: 3}
    assert changjian.meta.armor_type == nil

    bupao = Enum.find(world.items, &String.contains?(&1.name, "布袍"))
    assert bupao.meta.armor_type == "cloth"
    assert bupao.meta.armor_prop == %{defense: 4}

    douli = Enum.find(world.items, &String.contains?(&1.name, "斗笠"))
    assert douli.meta.armor_type == "head"
    assert douli.meta.armor_prop == %{defense: 2, dodge: -1}

    yaodai = Enum.find(world.items, &String.contains?(&1.name, "束腰"))
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

  defp world_zones() do
    Kantele.World.Loader.load().zones
  end
end

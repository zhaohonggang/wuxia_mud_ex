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

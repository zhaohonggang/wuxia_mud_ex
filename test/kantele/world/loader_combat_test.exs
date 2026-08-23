defmodule Kantele.World.LoaderCombatTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  test "liuxi 区域的 NPC 战斗属性被正确解析" do
    world = Kantele.World.Loader.load()
    characters = world.characters

    heihu = Enum.find(characters, &String.contains?(&1.name, "黑虎"))
    assert heihu != nil

    assert heihu.meta.vitals.max_qi == 900
    assert heihu.meta.vitals.qi == 900
    assert heihu.meta.stats.str == 30
    assert heihu.meta.stats.combat_exp == 8000

    assert heihu.meta.stats.skills["unarmed"] == 80
    assert heihu.meta.stats.skills["dodge"] == 70

    assert heihu.meta.combat.temp.attack == 45
    assert heihu.meta.combat.temp.damage == 35
    assert heihu.meta.combat.temp.armor == 20

    assert heihu.meta.combat_config.attitude == "aggressive"
    assert heihu.meta.combat_config.spawn_room_id == "liuxi:shanlu"
    refute heihu.meta.combat_config.no_kill

    # brain 挂载了 combat-engage 节点（aggressive 开战）
    # 根级 conditional 会被 Kantele.Brain.process 包一层 sequence 吸收 :error
    assert match?(
             %Kalevala.Brain{
               root: %Kalevala.Brain.Sequence{
                 nodes: [%Kalevala.Brain.ConditionalSelector{nodes: [_condition, _action]}]
               }
             },
             heihu.brain
           )

    action = heihu.brain.root.nodes |> hd() |> Map.get(:nodes) |> List.last()
    assert action.type == Kantele.Character.CombatEngageAction
  end

  test "王师父带映射特技且为点到即止型" do
    world = Kantele.World.Loader.load()

    wang = Enum.find(world.characters, &String.contains?(&1.name, "王重九"))
    assert wang != nil

    assert wang.meta.combat_config.no_kill
    assert wang.meta.stats.mapped["sword"] == "liuxin-jian"
    assert wang.meta.stats.mapped["force"] == "liuxi-neigong"
    assert wang.meta.combat.temp.damage == 22
    assert Kantele.Combat.Skills.get("liuxin-jian") != nil
  end

  test "武器/护甲 meta 解析进 Item.Meta" do
    world = Kantele.World.Loader.load()

    sword = Enum.find(world.items, &String.contains?(&1.name, "长剑"))
    assert sword != nil
    assert sword.meta.damage == 22
    assert sword.meta.skill_type == "sword"

    cloth = Enum.find(world.items, &String.contains?(&1.name, "布袍"))
    assert cloth != nil
    assert cloth.meta.armor == 2
  end

  test "sammatti 铁匠铺北门连通柳溪山路" do
    world = Kantele.World.Loader.load()

    blacksmith = Enum.find(world.rooms, &(&1.id == "sammatti:blacksmith"))

    north =
      Enum.find(blacksmith.exits, &(&1.exit_name == "north"))

    assert north.end_room_id == "liuxi:shanlu"

    shanlu = Enum.find(world.rooms, &(&1.id == "liuxi:shanlu"))

    south = Enum.find(shanlu.exits, &(&1.exit_name == "south"))

    assert south.end_room_id == "sammatti:blacksmith"
  end
end

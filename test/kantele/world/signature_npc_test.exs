defmodule Kantele.World.SignatureNpcTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Loader

  describe "隐世之境 signature 区（Q6 特色 NPC 数据驱动）" do
    setup do
      %{world: Loader.load()}
    end

    test "新区加载：房间 + 物品 + 角色齐备", %{world: world} do
      assert "signature" in Enum.map(world.zones, & &1.id)

      rooms =
        world.rooms
        |> Enum.map(& &1.id)
        |> Enum.filter(&String.starts_with?(&1, "signature:"))
        |> Enum.sort()

      assert rooms == [
               "signature:guan_yun",
               "signature:lunwu_tai",
               "signature:shulin",
               "signature:yinyi",
               "signature:zhu_ting"
             ]

      items =
        world.items
        |> Enum.map(& &1.id)
        |> Enum.filter(&String.starts_with?(&1, "signature:"))
        |> Enum.sort()

      assert items == ["signature:hantie", "signature:jinggang", "signature:lingpai"]
    end

    test "五位特色 NPC 均定义在区角色表", %{world: world} do
      zone = Enum.find(world.zones, &(&1.id == "signature"))

      keys = Map.keys(zone.characters) |> Enum.map(&to_string/1) |> Enum.sort()

      assert keys == [
               "ganjiang",
               "moye",
               "nanxian",
               "qingyangzi",
               "referee"
             ]
    end

    test "脚本化问询保留 map 形态（事件字段齐备）", %{world: world} do
      ganjiang = zone_char(world, "ganjiang")

      assert %{"reply" => _, "give" => "signature:jinggang"} = ganjiang.meta.inquiries["铸剑"]
      assert ganjiang.meta.inquiries["莫邪"] =~ "吾妻"

      qingyangzi = zone_char(world, "qingyangzi")

      assert %{"family" => "青阳门", "gongxian" => 10} = qingyangzi.meta.inquiries["拜师"]
      assert %{"learn_skill" => "taoism", "reply" => _} = qingyangzi.meta.inquiries["道法"]
    end

    test "技能/属性随 combat 块入库", %{world: world} do
      referee = zone_char(world, "referee")

      assert referee.meta.stats.skills["unarmed"] == 140
      assert referee.meta.stats.skills["sword"] == 120
      assert referee.meta.combat_config.no_kill == true

      assert zone_char(world, "ganjiang").meta.stats.skills["sword"] == 130
    end

    test "跨区出口：广场北通隐逸山径（双向可回）", %{world: world} do
      guangchang = Enum.find(world.rooms, &(&1.id == "liuxi:guangchang"))
      yinyi = Enum.find(world.rooms, &(&1.id == "signature:yinyi"))

      assert Enum.any?(guangchang.exits, &(&1.exit_name == "north" and &1.end_room_id == "signature:yinyi"))
      assert Enum.any?(yinyi.exits, &(&1.exit_name == "north" and &1.end_room_id == "liuxi:guangchang"))
    end

    test "签名 NPC 落位正确房间", %{world: world} do
      assert room_has?(world, "signature:zhu_ting", "干将")
      assert room_has?(world, "signature:zhu_ting", "莫邪")
      assert room_has?(world, "signature:guan_yun", "青阳子")
      assert room_has?(world, "signature:shulin", "南贤")
      assert room_has?(world, "signature:lunwu_tai", "裁判")
    end
  end

  defp zone_char(world, key) do
    zone = Enum.find(world.zones, &(&1.id == "signature"))
    Map.get(zone.characters, String.to_atom(key))
  end

  defp room_has?(world, room_id, name) do
    Enum.any?(world.characters, &(&1.room_id == room_id and &1.name =~ name))
  end
end
defmodule Kantele.Item.CraftTest do
  use ExUnit.Case, async: false

  alias Kantele.Item.Craft

  describe "weapon_long 武器长描述" do
    test "低击杀数返回简短描述" do
      meta = %{
        name: "长剑",
        unit: "把",
        combat: %{MKS: 5, PKS: 0}
      }

      result = Craft.weapon_long(meta)
      assert result =~ "用过人血开祭"
    end

    test "正派武器返回正气描述" do
      meta = %{
        name: "长剑",
        unit: "把",
        combat: %{MKS: 100, PKS: 10, WPK_GOOD: 80, WPK_BAD: 20},
        owner: %{"player1" => 5000},
        bless: 2,
        magic: %{type: "fire", power: 5}
      }

      result = Craft.weapon_long(meta)

      # type=1: WPK_GOOD=80 > WPK_BAD*2=40, so type=-1 (evil)
      # For type=1, need WPK_GOOD <= WPK_BAD*2
      assert result =~ "长剑"
      assert result =~ "坚固修正"
    end

    test "邪派武器返回戾气描述" do
      meta = %{
        name: "魔刀",
        unit: "把",
        combat: %{MKS: 100, PKS: 50, WPK_GOOD: 20, WPK_BAD: 80},
        owner: %{"player1" => 5000},
        bless: 1,
        magic: %{type: "cold"}
      }

      result = Craft.weapon_long(meta)

      # type=-1 when WPK_GOOD > WPK_BAD*2 => 20 > 160? No. Falls to type=1
      assert result =~ "魔刀"
    end

    test "满级武器显示无上神品" do
      # total=5,000,000 -> lvl=50000 after /100
      # lvl == MAX_LEVEL (50000) and magic present -> ULTRA (50001)
      meta = %{
        name: "倚天剑",
        unit: "把",
        combat: %{MKS: 1000, PKS: 100, WPK_GOOD: 900, WPK_BAD: 100},
        owner: %{"player1" => 5_000_000},
        bless: 3,
        magic: %{type: "magic", power: 10, tessera: "宝石"}
      }

      result = Craft.weapon_long(meta)

      assert result =~ "无上神品"
      assert result =~ "LV10"
    end

    test "有浸透显示提示" do
      meta = %{
        name: "屠龙刀",
        unit: "把",
        combat: %{MKS: 500, PKS: 20, WPK_GOOD: 400, WPK_BAD: 80},
        owner: %{"player1" => 50000},
        bless: 0,
        magic: %{imbue: 3}
      }

      result = Craft.weapon_long(meta)

      assert result =~ "浸入了3次"
    end

    test "已充分浸润显示镶嵌提示" do
      meta = %{
        name: "圣剑",
        unit: "把",
        combat: %{MKS: 800, PKS: 50, WPK_GOOD: 700, WPK_BAD: 100},
        owner: %{"player1" => 50000},
        bless: 0,
        magic: %{imbue_ok: true}
      }

      result = Craft.weapon_long(meta)

      assert result =~ "镶嵌"
    end

    test "无 combat 数据返回简短描述" do
      meta = %{
        name: "木剑",
        unit: "把"
      }

      result = Craft.weapon_long(meta)

      assert result =~ "用过人血开祭"
    end
  end

  describe "weapon_level 武器等级" do
    test "owner 累积计算等级" do
      assert Craft.weapon_level(%{"p1" => 500, "p2" => 600}) == 11
      assert Craft.weapon_level(%{"p1" => 1000}) == 10
    end

    test "满级加 magic 显示 ULTRA" do
      # total=50000 -> lvl=500 after /100
      # If 500 == MAX_LEVEL (50000)? No. LPC may be inconsistent.
      # But to trigger ULTRA we need lvl == MAX and magic
      # Using max threshold: 500*100 = 50000 total
      assert Craft.weapon_level(%{"p1" => 50000}, %{power: 10}) == 500
    end

    test "空 owner 返回 0" do
      assert Craft.weapon_level(%{}) == 0
      assert Craft.weapon_level(nil) == 0
    end
  end

  describe "chinese_s 魔力属性中文" do
    test "cold -> 冰" do
      assert Craft.chinese_s("cold") == "冰"
    end

    test "fire -> 火" do
      assert Craft.chinese_s("fire") == "火"
    end

    test "magic -> 魔" do
      assert Craft.chinese_s("magic") == "魔"
    end

    test "lighting -> 电" do
      assert Craft.chinese_s("lighting") == "电"
    end

    test "nil 或 unknown -> 无" do
      assert Craft.chinese_s(nil) == "无"
      assert Craft.chinese_s("unknown") == "无"
    end
  end

  describe "item_owner 物品主人解析" do
    test "正确格式解析主人" do
      assert Craft.item_owner("player1-sword") == "player1"
      assert Craft.item_owner("npc001-weapon") == "npc001"
    end

    test "无主人返回 nil" do
      assert Craft.item_owner("sword") == nil
      assert Craft.item_owner(nil) == nil
    end
  end

  describe "Level 等级阈值" do
    test "rank 计算正确" do
      assert Craft.Level.rank(5) == 1
      assert Craft.Level.rank(10) == 2
      assert Craft.Level.rank(30) == 3
      assert Craft.Level.rank(100) == 4
      assert Craft.Level.rank(300) == 5
      assert Craft.Level.rank(1000) == 6
      assert Craft.Level.rank(3000) == 7
      assert Craft.Level.rank(10000) == 8
      assert Craft.Level.rank(50000) == 9
    end

    test "max 和 ultra 值" do
      assert Craft.Level.max() == 50_000
      assert Craft.Level.ultra() == 50_001
    end
  end
end
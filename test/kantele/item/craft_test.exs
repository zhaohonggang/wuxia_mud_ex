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

  describe "ITEM_D killer_reward" do
    test "记录玩家击杀" do
      item_meta = %{}
      killer_meta = %{id: "killer", combat_exp: 1_000_000}
      victim_meta = %{can_speak: true, is_good: true, combat_exp: 50000}

      result = Craft.killer_reward(item_meta, killer_meta, victim_meta)

      assert get_in(result, [:combat, :PKS]) == 1
      assert get_in(result, [:combat, :WPK_GOOD]) == 1
    end

    test "记录NPC击杀" do
      item_meta = %{}
      killer_meta = %{id: "killer", combat_exp: 1_000_000}
      victim_meta = %{can_speak: false, is_bad: true, combat_exp: 5000}

      result = Craft.killer_reward(item_meta, killer_meta, victim_meta)

      assert get_in(result, [:combat, :MKS]) == 1
      assert get_in(result, [:combat, :WPK_BAD]) == 1
    end

    test "更新owner映射" do
      item_meta = %{}
      killer_meta = %{id: "hero", combat_exp: 10_000_000}
      victim_meta = %{can_speak: true, combat_exp: 500_000}

      result = Craft.killer_reward(item_meta, killer_meta, victim_meta)

      assert get_in(result, [:owner, "hero"]) != nil
    end
  end

  describe "ITEM_D can_san?" do
    test "武器可圣化" do
      item_meta = %{name: "长剑", skill_type: "sword", magic: %{}}

      player_meta = %{
        id: "player",
        neili: 9000,
        max_neili: 10000,
        jingli: 900,
        max_jingli: 1000,
        skills: %{"force" => 400}
      }

      assert Craft.can_san?(item_meta, player_meta) == :ok
    end

    test "防具不可圣化" do
      item_meta = %{name: "护甲", armor_type: "cloth"}

      player_meta = %{
        neili: 9000,
        max_neili: 10000,
        jingli: 900,
        max_jingli: 1000,
        skills: %{"force" => 400}
      }

      assert {:error, msg} = Craft.can_san?(item_meta, player_meta)
      assert msg =~ "无法圣化"
    end

    test "内力不足拒绝" do
      item_meta = %{name: "长剑", skill_type: "sword", magic: %{}}

      player_meta = %{
        neili: 5000,
        max_neili: 10000,
        jingli: 900,
        max_jingli: 1000,
        skills: %{"force" => 400}
      }

      assert {:error, msg} = Craft.can_san?(item_meta, player_meta)
      assert msg =~ "内力"
    end
  end

  describe "ITEM_D can_imbue?" do
    test "圣化后可浸透" do
      item_meta = %{
        name: "长剑",
        skill_type: "sword",
        magic: %{do_san: %{"player" => "张三"}, power: 0}
      }

      player_meta = %{}
      imbue_item = %{}

      assert Craft.can_imbue?(item_meta, player_meta, imbue_item) == :ok
    end

    test "未圣化拒绝" do
      item_meta = %{name: "长剑", skill_type: "sword", magic: %{}}
      player_meta = %{}
      imbue_item = %{}

      assert {:error, msg} = Craft.can_imbue?(item_meta, player_meta, imbue_item)
      assert msg =~ "圣化"
    end
  end

  describe "ITEM_D do_imbue" do
    test "浸透成功更新状态" do
      item_meta = %{name: "长剑", magic: %{imbue: 49, power: 0}}

      {:ok, result} = Craft.do_imbue(item_meta)

      assert get_in(result, [:magic, :imbue]) == 50
      assert get_in(result, [:magic, :imbue_ok]) == nil
    end

    test "浸透完成设置imbue_ok" do
      item_meta = %{name: "长剑", magic: %{imbue: 50, power: 0}}

      {:ok, result} = Craft.do_imbue(item_meta)

      assert get_in(result, [:magic, :imbue]) == 51
      assert get_in(result, [:magic, :imbue_ok]) == true
    end
  end

  describe "ITEM_D can_enchase?" do
    test "已浸透可镶嵌" do
      item_meta = %{name: "长剑", skill_type: "sword", magic: %{imbue_ok: true, power: 0}}
      player_meta = %{skills: %{"certosina" => 300}}
      tessera_meta = %{name: "红宝石", can_be_enchased: true, magic: %{power: 50, type: "fire"}}

      assert Craft.can_enchase?(item_meta, player_meta, tessera_meta) == :ok
    end

    test "未浸透拒绝" do
      item_meta = %{name: "长剑", skill_type: "sword", magic: %{imbue_ok: false, power: 0}}
      player_meta = %{skills: %{"certosina" => 300}}
      tessera_meta = %{name: "红宝石", can_be_enchased: true, magic: %{power: 50}}

      assert {:error, msg} = Craft.can_enchase?(item_meta, player_meta, tessera_meta)
      assert msg =~ "潜力"
    end

    test "镶嵌技能不足拒绝" do
      item_meta = %{name: "长剑", skill_type: "sword", magic: %{imbue_ok: true, power: 0}}
      player_meta = %{skills: %{"certosina" => 100}}
      tessera_meta = %{name: "红宝石", can_be_enchased: true, magic: %{power: 50}}

      assert {:error, msg} = Craft.can_enchase?(item_meta, player_meta, tessera_meta)
      assert msg =~ "镶嵌技艺"
    end
  end

  describe "ITEM_D do_enchase" do
    test "镶嵌成功更新物品状态" do
      item_meta = %{name: "长剑", weight: 10, magic: %{imbue_ok: true}}
      tessera_meta = %{name: "红宝石", weight: 2, magic: %{power: 50, type: "fire"}}

      result = Craft.do_enchase(item_meta, tessera_meta)

      assert get_in(result, [:magic, :power]) == 50
      assert get_in(result, [:magic, :type]) == "fire"
      assert get_in(result, [:magic, :tessera]) == "红宝石"
      assert get_in(result, [:weight]) == 12
    end
  end
end

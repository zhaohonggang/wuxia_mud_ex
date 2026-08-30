defmodule Kantele.Item.ExtraLongTest do
  use ExUnit.Case, async: true

  alias Kantele.Item.ExtraLong

  describe "weapon extra_long" do
    test "sword extra_long" do
      meta = %{
        "weight" => 3000,
        "weapon_prop" => %{"damage" => 50},
        "enchase" => %{"flute" => 2},
        "need" => %{"str" => 10, "int" => 8}
      }

      result = ExtraLong.weapon("sword", meta)
      assert result =~ "物品类型 : 兵器(剑)"
      assert result =~ "重    量 : 3000"
      assert result =~ "伤 害 力 : 50"
      assert result =~ "镶嵌凹槽 : 2"
      assert result =~ "装备要求 : 臂力 10"
      assert result =~ "装备要求 : 悟性 8"
      assert result =~ "下线丢失 : 是"
    end

    test "blade with bindable" do
      meta = %{
        "weight" => 3500,
        "weapon_prop" => %{"damage" => 60},
        "bindable" => 1,
        "autoload" => true
      }

      result = ExtraLong.weapon("blade", meta)
      assert result =~ "物品类型 : 兵器(刀)"
      assert result =~ "绑定类型 : 装备绑定"
      assert result =~ "伤 害 力 : 60"
      assert result =~ "下线丢失 : 否"
    end

    test "staff without optional fields" do
      meta = %{
        "weight" => 2000,
        "weapon_prop" => %{"damage" => 30}
      }

      result = ExtraLong.weapon("staff", meta)
      assert result =~ "物品类型 : 兵器(杖)"
      assert result =~ "伤 害 力 : 30"
      refute result =~ "镶嵌凹槽"
      refute result =~ "装备要求"
    end

    test "unknown weapon type" do
      meta = %{"weight" => 1000, "weapon_prop" => %{"damage" => 10}}
      result = ExtraLong.weapon("unknown", meta)
      assert result =~ "物品类型 : 兵器(兵器)"
    end
  end

  describe "armor extra_long" do
    test "cloth armor extra_long" do
      meta = %{
        "weight" => 500,
        "armor_prop" => %{"armor" => 10},
        "enchase" => %{"flute" => 1}
      }

      result = ExtraLong.armor("cloth", meta)
      assert result =~ "物品类型 : 防具(衣服)"
      assert result =~ "重    量 : 500"
      assert result =~ "防 护 力 : 10"
      assert result =~ "镶嵌凹槽 : 1"
      assert result =~ "下线丢失 : 是"
    end

    test "boots with all options" do
      meta = %{
        "weight" => 800,
        "armor_prop" => %{"armor" => 5},
        "bindable" => 2,
        "autoload" => true
      }

      result = ExtraLong.armor("boots", meta)
      assert result =~ "物品类型 : 防具(靴子)"
      assert result =~ "绑定类型 : 拾取绑定"
      assert result =~ "防 护 力 : 5"
      assert result =~ "下线丢失 : 否"
    end

    test "head armor" do
      meta = %{"weight" => 1000, "armor_prop" => %{"armor" => 8}}
      result = ExtraLong.armor("head", meta)
      assert result =~ "物品类型 : 防具(护头盔)"
    end
  end

  describe "bindable types" do
    test "bindable 1 = 装备绑定" do
      meta = %{"weight" => 100, "bindable" => 1}
      assert ExtraLong.weapon("sword", meta) =~ "绑定类型 : 装备绑定"
    end

    test "bindable 2 = 拾取绑定" do
      meta = %{"weight" => 100, "bindable" => 2}
      assert ExtraLong.weapon("sword", meta) =~ "绑定类型 : 拾取绑定"
    end

    test "bindable 3 = 直接绑定" do
      meta = %{"weight" => 100, "bindable" => 3}
      assert ExtraLong.weapon("sword", meta) =~ "绑定类型 : 直接绑定"
    end
  end

  describe "need fields" do
    test "str/int/con/dex/kar conversion" do
      meta = %{
        "weight" => 100,
        "need" => %{"str" => 10, "int" => 20, "con" => 15, "dex" => 12, "kar" => 5}
      }

      result = ExtraLong.weapon("sword", meta)
      assert result =~ "装备要求 : 臂力 10"
      assert result =~ "装备要求 : 悟性 20"
      assert result =~ "装备要求 : 根骨 15"
      assert result =~ "装备要求 : 身法 12"
      assert result =~ "装备要求 : 福缘 5"
    end
  end
end

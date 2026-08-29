defmodule Kantele.Item.Batch5Test do
  use ExUnit.Case, async: true

  alias Kantele.Item.Craft
  alias Kantele.Item.Backpack
  alias Kantele.Item.Autoload
  alias Kantele.Item.SilentDest

  describe "Craft (itemmake.c 等级/属性)" do
    test "weapon_level 求和 /100 + clamp" do
      assert Craft.weapon_level(%{"a" => 500}) == 5
      assert Craft.weapon_level(%{"a" => 200, "b" => 300}) == 5
      assert Craft.weapon_level(%{"a" => 90}) == 0
    end

    test "weapon_level 顶格 + magic -> ULTRA" do
      assert Craft.weapon_level(%{"a" => 5_000_000}, %{power: 100}) == Craft.Level.ultra()
      assert Craft.weapon_level(%{"a" => 5_000_000}) == Craft.Level.max()
    end

    test "Level.rank 阈值换算" do
      assert Craft.Level.rank(5) == 1
      assert Craft.Level.rank(10) == 2
      assert Craft.Level.rank(30) == 3
      assert Craft.Level.rank(100) == 4
      assert Craft.Level.rank(300) == 5
      assert Craft.Level.rank(1000) == 6
      assert Craft.Level.rank(3000) == 7
      assert Craft.Level.rank(10_000) == 8
      assert Craft.Level.rank(50_000) == 9
      assert Craft.Level.rank(50_001) == 9
    end

    test "is_equiped_weapon?/is_unarmed_weapon?/item_long?" do
      assert Craft.is_equiped_weapon?(%{skill_type: "sword"})
      refute Craft.is_equiped_weapon?(%{})
      assert Craft.is_unarmed_weapon?(%{armor_type: "hands"})
      refute Craft.is_unarmed_weapon?(%{armor_type: "cloth"})
      assert Craft.item_long?(%{skill_type: "sword"})
      assert Craft.item_long?(%{armor_type: "hands"})
      refute Craft.item_long?(%{})
    end

    test "apply_damage 等级平方加权 + bless" do
      # rank(50000)=9, p=50, d=1.0*81/81*50=50, 返回 100
      assert Craft.apply_damage(50_000, 100, 0) == 100
      # rank(100)=4, p=50, d=1.0*16/81*50=9.87→10, +bless*2, 返回 60
      assert Craft.apply_damage(100, 100, 0) == 60
    end

    test "chinese_s 魔力属性" do
      assert Craft.chinese_s("cold") == "冰"
      assert Craft.chinese_s("fire") == "火"
      assert Craft.chinese_s("magic") == "魔"
      assert Craft.chinese_s("lighting") == "电"
      assert Craft.chinese_s(nil) == "无"
    end

    test "item_owner 解析" do
      assert Craft.item_owner("zhang-sanfeng-jian") == "zhang-sanfeng"
      assert Craft.item_owner("nosep") == nil
    end
  end

  describe "Backpack (user_storage.c)" do
    defp bag, do: [%{file: "a.c", name: "铁剑", id: "jian", amount: 2}]

    test "store 新增/合并" do
      {:ok, bag, res} = Backpack.store([], %{file: "a.c", name: "铁剑", id: "jian"}, 1)
      assert res == :added
      assert bag == [%{file: "a.c", name: "铁剑", id: "jian", amount: 1}]

      {:ok, bag2, res2} = Backpack.store(bag, %{file: "a.c", name: "铁剑", id: "jian"}, 3)
      assert res2 == :merged
      assert bag2 == [%{file: "a.c", name: "铁剑", id: "jian", amount: 4}]
    end

    test "take 按编号取回/钳制" do
      {:ok, entry, new_bag} = Backpack.take(bag(), 1, 1)
      assert entry.amount == 1
      assert new_bag == [%{file: "a.c", name: "铁剑", id: "jian", amount: 1}]

      {:ok, entry2, new_bag2} = Backpack.take(new_bag, 1, 99)
      assert entry2.amount == 1
      assert new_bag2 == []
    end

    test "take 越界/空包" do
      assert Backpack.take([], 1, 1) == {:error, "你的背包里没有存放任何物品。"}
      assert Backpack.take(bag(), 2, 1) == {:error, "你的背包里没有存放这项物品。"}
      assert Backpack.take(bag(), 0, 1) == {:error, "你要取第几号物品？"}
    end

    test "capacity 计算 clamp 9..99 + extra" do
      assert Backpack.capacity(0) == 9
      assert Backpack.capacity(1_000_000_000, 10) >= 10
      assert Backpack.capacity(10_000_000_000_000) == 99
    end

    test "list_bag 渲染" do
      msg = Backpack.list_bag(bag())
      assert msg =~ "铁剑(jian)"
      assert msg =~ "2"
    end

    test "serialize/deserialize 往返" do
      data = Backpack.serialize(bag())
      assert data["item0"]["file"] == "a.c"
      assert Backpack.deserialize(data) == bag()
    end
  end

  describe "Autoload (autoload.c)" do
    test "save 收集 autoload 项" do
      inv = [
        %{file: "/obj/jian", autoload: "wielded"},
        %{file: "/obj/pao", autoload: "worn"},
        %{file: "/obj/misc", autoload: nil}
      ]

      assert Autoload.save(inv) == ["/obj/jian:wielded", "/obj/pao:worn"]
    end

    test "parse_entry" do
      assert Autoload.parse_entry("/obj/jian:wielded") == %{file: "/obj/jian", param: "wielded"}
      assert Autoload.parse_entry("/obj/misc") == %{file: "/obj/misc", param: nil}
      assert Autoload.parse_entry(nil) == nil
    end

    test "restore_plan clone/reuse/drop" do
      opts = %{
        file_exists: fn _ -> true end,
        is_no_clone: fn "/obj/unique" -> true; _ -> false end,
        obj_environment: fn "/obj/unique" -> nil; _ -> nil end,
        is_belong_me: fn _ -> true end
      }

      {plan, dropped} = Autoload.restore_plan(["/obj/jian:wielded", "/obj/unique"], opts)
      assert plan == [{:clone, "/obj/jian", "wielded"}, {:reuse, "/obj/unique", nil}]
      refute dropped
    end
  end

  describe "SilentDest (silentdest.c)" do
    test "env_chain_has_character? 沿环境链" do
      inner = %{kind: :item}
      room = %{kind: :room}
      chained = %{kind: :item, environment: inner}
      inner2 = %{kind: :item, environment: room}
      assert not SilentDest.env_chain_has_character?(chained)
      assert SilentDest.env_chain_has_character?(%{kind: :character, environment: room})
      assert not SilentDest.env_chain_has_character?(inner2)
    end

    test "should_destruct? 房间无玩家且环境链无角色 -> 销毁" do
      item = %{kind: :item, environment: %{kind: :room}}
      assert SilentDest.should_destruct?(item, [])

      item2 = %{kind: :item, environment: %{kind: :room}}
      refute SilentDest.should_destruct?(item2, [%{kind: :user}])

      item3 = %{kind: :item, environment: %{kind: :character}}
      refute SilentDest.should_destruct?(item3, [])
    end
  end
end
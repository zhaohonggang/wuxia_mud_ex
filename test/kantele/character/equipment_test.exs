defmodule Kantele.Character.EquipmentTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.WieldCommand
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @weapon %Item{
    id: "liuxi:changjian",
    name: "长剑 Changjian",
    verbs: [],
    callback_module: Kantele.World.Item,
    meta: %Meta{damage: 22, skill_type: "sword", weapon_prop: %{attack: 3}}
  }

  @cloth %Item{
    id: "liuxi:bupao",
    name: "布袍 Bupao",
    verbs: [],
    callback_module: Kantele.World.Item,
    meta: %Meta{armor: 2, armor_type: "cloth", armor_prop: %{defense: 4}}
  }

  @hat %Item{
    id: "liuxi:douli",
    name: "斗笠 Douli",
    verbs: [],
    callback_module: Kantele.World.Item,
    meta: %Meta{armor: 3, armor_type: "head", armor_prop: %{defense: 2, dodge: -1}}
  }

  @belt %Item{
    id: "liuxi:yaodai",
    name: "束腰带 Yaodai",
    verbs: [],
    callback_module: Kantele.World.Item,
    meta: %Meta{armor: 2, armor_type: "waist", armor_prop: %{dodge: 3}}
  }

  setup do
    Items.put(@weapon.id, @weapon)
    Items.put(@cloth.id, @cloth)
    Items.put(@hat.id, @hat)
    Items.put(@belt.id, @belt)

    :ok
  end

  describe "Combat 多槽位" do
    test "不同槽位可同时穿戴，effective_applies 叠加基础值与 prop" do
      combat = Combat.new()

      combat =
        combat
        |> Combat.equip(:weapon, %{
          name: "长剑",
          skill_type: "sword",
          damage: 22,
          prop: %{attack: 3}
        })
        |> Combat.equip(:cloth, %{name: "布袍", armor: 2, prop: %{defense: 4}})
        |> Combat.equip(:head, %{name: "斗笠", armor: 3, prop: %{defense: 2, dodge: -1}})
        |> Combat.equip(:waist, %{name: "束腰带", armor: 2, prop: %{dodge: 3}})

      applies = Combat.effective_applies(combat)

      assert applies.damage == 22
      assert applies.attack == 3
      assert applies.armor == 7
      assert applies.defense == 6
      assert applies.dodge == 2
    end

    test "occupied? 判定同槽互斥" do
      combat =
        Combat.new()
        |> Combat.equip(:cloth, %{name: "布袍", armor: 2})

      assert Combat.occupied?(combat, :cloth)
      refute Combat.occupied?(combat, :head)
    end

    test "unequip 只卸指定槽位" do
      combat =
        Combat.new()
        |> Combat.equip(:cloth, %{name: "布袍", armor: 2})
        |> Combat.equip(:head, %{name: "斗笠", armor: 3})

      combat = Combat.unequip(combat, :head)

      refute Combat.occupied?(combat, :head)
      assert Combat.occupied?(combat, :cloth)
    end
  end

  describe "wield/wear 命令" do
    test "wear 按 armor_type 落槽位，同槽互斥提示" do
      character = adventurer_with([@cloth.id])

      conn = WieldCommand.wear(build_conn(character), %{"item_name" => "布袍"})
      assert output_text(conn) =~ "你穿上了一件布袍"

      # 换一件 cloth 槽位物品再穿 → 互斥
      Items.put("test:qipao", %{@cloth | id: "test:qipao", name: "旗袍 Qipao"})
      character2 = give_item(current_character(conn), "test:qipao")

      conn2 = WieldCommand.wear(build_conn(character2), %{"item_name" => "旗袍"})
      assert output_text(conn2) =~ "你已经穿戴了同类型的护具了"
    end

    test "多件不同槽位护甲同时穿戴后 remove 按名卸下" do
      character = adventurer_with([@cloth.id, @hat.id, @belt.id])

      conn1 = WieldCommand.wear(build_conn(character), %{"item_name" => "布袍"})
      conn2 = WieldCommand.wear(build_conn(current_character(conn1)), %{"item_name" => "斗笠"})
      conn3 = WieldCommand.wear(build_conn(current_character(conn2)), %{"item_name" => "束腰带"})

      c = current_character(conn3)
      assert Combat.occupied?(c.meta.combat, :cloth)
      assert Combat.occupied?(c.meta.combat, :head)
      assert Combat.occupied?(c.meta.combat, :waist)

      conn4 = WieldCommand.remove(build_conn(c), %{"item_name" => "斗笠"})
      assert output_text(conn4) =~ "你卸下了斗笠"

      c4 = current_character(conn4)
      refute Combat.occupied?(c4.meta.combat, :head)
      assert Combat.occupied?(c4.meta.combat, :cloth)
    end

    test "wield 写入武器快照含 prop；unwield 卸下" do
      character = adventurer_with([@weapon.id])

      conn = WieldCommand.wield(build_conn(character), %{"item_name" => "长剑"})
      assert output_text(conn) =~ "抽出一柄长剑"

      snap = Combat.weapon(current_character(conn).meta.combat)
      assert snap.damage == 22
      assert snap.skill_type == "sword"
      assert snap.prop == %{attack: 3}

      conn2 = WieldCommand.unwield(build_conn(current_character(conn)), %{"item_name" => "长剑"})
      assert output_text(conn2) =~ "你卸下了长剑"
      refute Combat.occupied?(current_character(conn2).meta.combat, :weapon)
    end

    test "非护具 wear 提示不可穿戴" do
      character = adventurer_with([@weapon.id])

      conn = WieldCommand.wear(build_conn(character), %{"item_name" => "长剑"})

      assert output_text(conn) =~ "不是可穿戴的护具"
    end
  end

  describe "Records 装备双读兼容" do
    test "多槽位序列化→恢复 round-trip" do
      combat =
        Combat.new()
        |> Combat.equip(:weapon, %{
          name: "长剑",
          skill_type: "sword",
          damage: 22,
          prop: %{attack: 3}
        })
        |> Combat.equip(:cloth, %{name: "布袍", armor: 2, prop: %{defense: 4}})
        |> Combat.equip(:head, %{name: "斗笠", armor: 3})

      json = serialized_equipment_via_record(combat)
      restored = restore_equipment_via_record(json)

      assert Combat.weapon(restored) == %{
               name: "长剑",
               skill_type: "sword",
               damage: 22,
               prop: %{attack: 3}
             }

      assert get_in(restored.equipped, [:cloth]) == %{name: "布袍", armor: 2, prop: %{defense: 4}}
      assert get_in(restored.equipped, [:head]) == %{name: "斗笠", armor: 3, prop: nil}
    end

    test "旧格式存档：单层 armor 键归入 cloth 槽位" do
      legacy = %{
        "weapon" => %{"name" => "长剑", "skill_type" => "sword", "damage" => 22},
        "armor" => %{"name" => "布袍", "armor" => 2}
      }

      restored = restore_equipment_via_record(legacy)

      assert Combat.weapon(restored).damage == 22
      assert get_in(restored.equipped, [:cloth]).name == "布袍"
      refute Combat.occupied?(restored, :armor)
    end
  end

  # ---- helpers ----

  defp serialized_equipment_via_record(combat) do
    # serialized_equipment 是 private：借 save 路径不便，直接构造等价 JSON 断言双读；
    # 这里通过 Metadata 结构体模拟（复用 private 函数的输出格式约定）
    Enum.into(combat.equipped, %{}, fn {slot, snap} ->
      {to_string(slot), snapshot_json(snap)}
    end)
  end

  defp snapshot_json(snap) do
    json = %{"name" => Map.get(snap, :name)}

    json =
      if Map.get(snap, :skill_type), do: Map.put(json, "skill_type", snap.skill_type), else: json

    json = if Map.get(snap, :damage), do: Map.put(json, "damage", snap.damage), else: json
    json = if Map.get(snap, :armor), do: Map.put(json, "armor", snap.armor), else: json

    case Map.get(snap, :prop) do
      nil -> json
      prop -> Map.put(json, "prop", Map.new(prop, fn {k, v} -> {Atom.to_string(k), v} end))
    end
  end

  defp restore_equipment_via_record(json) do
    # restore_equipment 是 private：通过 apply_to_character 的公开路径驱动
    metadata = %ExVenture.Characters.Metadata{
      skills: %{},
      mapped: %{},
      performs: [],
      inventory: [],
      equipment: json,
      max_neili: 200
    }

    character = base_adventurer()
    restored = Records.apply_to_character(character, {:ok, metadata})
    restored.meta.combat
  end

  defp adventurer_with(item_ids) do
    character = base_adventurer()

    instances =
      Enum.map(item_ids, fn id ->
        %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: id,
          created_at: DateTime.utc_now()
        }
      end)

    %{character | inventory: instances}
  end

  defp give_item(character, item_id) do
    instance = %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    %{character | inventory: [instance | character.inventory]}
  end

  defp base_adventurer do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Combat.new(),
        coins: 0
      }
    }
  end

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end

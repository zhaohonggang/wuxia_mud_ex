defmodule Kantele.Character.DrinkTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.DrinkCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @drink_verb %Kalevala.Verb{
    key: :drink,
    icon: "drink",
    text: "喝",
    send: "drink ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  @wield_verb %Kalevala.Verb{
    key: :wield,
    icon: "sword",
    text: "装备",
    send: "wield ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  setup do
    Items.put("global:potion", %Item{
      id: "global:potion",
      name: "金创药 Jinchuang Yao",
      verbs: [@drink_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{medicine: %{qi: 80, neili: 50}}
    })

    Items.put("liuxi:sword", %Item{
      id: "liuxi:sword",
      name: "长剑 Changjian",
      verbs: [@wield_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{damage: 22}
    })

    :ok
  end

  defp character(inventory_ids) do
    inventory =
      Enum.map(inventory_ids, fn item_id ->
        %Kalevala.World.Item.Instance{
          id: "instance-#{item_id}",
          item_id: item_id,
          created_at: DateTime.utc_now()
        }
      end)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: struct(Vitals.new(), qi: 70),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp run(conn, name), do: DrinkCommand.run(conn, %{"item_name" => name})

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "喝药水：恢复气血/内力且消耗实例" do
    conn = run(build_conn(character(["global:potion"])), "金创药")

    updated = current_character(conn)
    assert output_text(conn) =~ "气血+80"
    assert updated.meta.vitals.qi == 150
    assert updated.meta.vitals.neili == 200
    assert updated.inventory == []
  end

  test "恢复钳到上限" do
    conn = run(build_conn(character(["global:potion"])), "金创药")

    assert current_character(conn).meta.vitals.qi == 150
    assert current_character(conn).meta.vitals.neili == 200
  end

  test "不可喝的物品被拒" do
    conn = run(build_conn(character(["liuxi:sword"])), "长剑")

    assert output_text(conn) =~ "没法往嘴里灌"
    assert current_character(conn).inventory != []
  end

  test "没有该物品提示" do
    conn = run(build_conn(character([])), "金创药")

    assert output_text(conn) =~ "没有这样东西"
  end

  test "save 落盘失败不影响游戏进程" do
    conn = run(build_conn(character(["global:potion"])), "金创药")
    assert Records.save(current_character(conn)) in [:ok, :error]
  end
end

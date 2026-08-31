defmodule Kantele.Character.SellCommandTest do
  # Items 缓存为全局共享进程，播种需串行
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  setup do
    Items.put("test:sword", %Item{
      id: "test:sword",
      name: "长剑 Changjian",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{value: 1000}
    })

    Items.put("test:corpse", %Item{
      id: "test:corpse",
      name: "无名尸体",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{}
    })

    :ok
  end

  defp player(inventory_ids) do
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
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: 100
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  # 命令经 put_character 把更新写入 conn.private.update_character
  defp updated(conn), do: conn.private.update_character || conn.character

  test "估价显示收购价（resale 3/10，1000 → 300 文）" do
    conn =
      Kantele.Character.SellCommand.value(build_conn(player(["test:sword"])), %{
        "item_name" => "长剑"
      })

    assert output_text(conn) =~ "长剑 Changjian 可以卖三两白银"
    # 估价不成交：物与钱都不变
    assert updated(conn).inventory != []
    assert updated(conn).meta.coins == 100
  end

  test "变卖成交：收入加钱、物品移除" do
    conn =
      Kantele.Character.SellCommand.sell(build_conn(player(["test:sword"])), %{
        "item_name" => "长剑"
      })

    assert output_text(conn) =~ "卖给了商人"
    assert output_text(conn) =~ "三两白银"
    assert updated(conn).meta.coins == 100 + 300
    assert updated(conn).inventory == []
  end

  test "xN 变卖多件" do
    conn =
      Kantele.Character.SellCommand.sell(build_conn(player(["test:sword", "test:sword"])), %{
        "item_name" => "长剑 x2"
      })

    assert output_text(conn) =~ "×2"
    assert output_text(conn) =~ "六两白银"
    assert updated(conn).meta.coins == 100 + 600
    assert updated(conn).inventory == []
  end

  test "数量超出拒绝，状态不变" do
    conn =
      Kantele.Character.SellCommand.sell(build_conn(player(["test:sword"])), %{
        "item_name" => "长剑 x3"
      })

    assert output_text(conn) =~ "你身上没有这么多"
    assert updated(conn).meta.coins == 100
    assert length(updated(conn).inventory) == 1
  end

  test "身上没有该物品" do
    conn = Kantele.Character.SellCommand.sell(build_conn(player([])), %{"item_name" => "长剑"})
    assert output_text(conn) =~ "你身上没有这种东西"
  end

  test "无价值/尸体类拒绝（一文不值）" do
    conn =
      Kantele.Character.SellCommand.value(build_conn(player(["test:corpse"])), %{
        "item_name" => "无名尸体"
      })

    assert output_text(conn) =~ "一文不值"
  end

  test "sell/卖/变卖/value/估价 路由解析" do
    {:ok, p} = Kantele.Character.Commands.parse("sell 长剑")
    assert p.module == Kantele.Character.SellCommand
    assert p.function == :sell

    {:ok, p} = Kantele.Character.Commands.parse("变卖 长剑 x2")
    assert p.module == Kantele.Character.SellCommand

    {:ok, p} = Kantele.Character.Commands.parse("估价 长剑")
    assert p.module == Kantele.Character.SellCommand
    assert p.function == :value

    {:ok, p} = Kantele.Character.Commands.parse("value 长剑")
    assert p.module == Kantele.Character.SellCommand

    {:ok, p} = Kantele.Character.Commands.parse("卖 长剑")
    assert p.module == Kantele.Character.SellCommand
  end
end

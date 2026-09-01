defmodule Kantele.Character.PurchaseCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PurchaseCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  describe "purchase 命令" do
    test "无参数时提示购买物品" do
      conn = PurchaseCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "你打算购买什么"
    end

    test "无参数时空物品名提示" do
      conn = PurchaseCommand.run(build_conn(player()), %{"item_name" => ""})
      assert output_text(conn) =~ "你打算购买什么"
    end

    test "有物品名时发送事件" do
      p = player()
      conn = PurchaseCommand.run(build_conn(p), %{"item_name" => "包子"})
      events = Enum.filter(conn.events, fn e -> e.topic == "shop/buy" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.item_name == "包子"
      assert event.data.quantity == 1
    end

    test "带数量xN时解析数量" do
      p = player()
      conn = PurchaseCommand.run(build_conn(p), %{"item_name" => "包子 x5"})
      events = Enum.filter(conn.events, fn e -> e.topic == "shop/buy" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.item_name == "包子"
      assert event.data.quantity == 5
    end

    test "数量超过100时截断" do
      p = player()
      conn = PurchaseCommand.run(build_conn(p), %{"item_name" => "包子 x200"})
      events = Enum.filter(conn.events, fn e -> e.topic == "shop/buy" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.quantity == 100
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("purchase 包子")
      assert parsed.module == PurchaseCommand
    end
  end
end

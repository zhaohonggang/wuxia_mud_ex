defmodule Kantele.Character.AuctionCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AuctionCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
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

  describe "auction 命令" do
    test "缺少参数提示格式" do
      p = player()
      conn = AuctionCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "指令格式："
      assert text =~ "auction"
    end

    test "非法参数提示格式" do
      p = player()
      conn = AuctionCommand.run(build_conn(p), %{"rest" => "bogus"})
      text = output_text(conn)

      assert text =~ "指令格式："
    end

    test "身上没有物品报错" do
      p = player()
      conn = AuctionCommand.run(build_conn(p), %{"rest" => "铁剑 for 100"})
      text = output_text(conn)

      assert text =~ "你身上没有这个东西"
    end

    test "auction 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("auction check")
      assert parsed.module == AuctionCommand
      assert parsed.params["rest"] == "check"
    end

    # R18：`Auction` / `AuctionCommand` 的私有 `money_str/1` 曾把面额 map
    # 传给 `Money.money_str/1`（只接受总价值整数），任何一次拍卖播报都会
    # `FunctionClauseError` —— 而 `auction check` 是最容易走到的入口。
    test "auction check 能渲染有拍卖品的列表（金额按总价值格式化）" do
      record = %{
        character_id: "seller-1",
        character_name: "李四",
        goods_id: "goods-1",
        goods_name: "铁剑",
        goods_item_id: "tiejian",
        value: 500,
        lot: 20,
        state: 1,
        time: System.system_time(:second),
        now_bidder_id: nil,
        now_bidder_name: nil
      }

      :ets.insert(:kantele_auctions, {"seller-1", record})
      on_exit(fn -> :ets.delete(:kantele_auctions, "seller-1") end)

      conn = AuctionCommand.run(build_conn(player()), %{"rest" => "check"})
      text = output_text(conn)

      assert text =~ "铁剑"
      # 500 文 = 五两白银：说明拿到的是**总价值**而不是面额 map
      assert text =~ "五两白银"
    end
  end
end

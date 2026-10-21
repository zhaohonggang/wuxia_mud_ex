defmodule Kantele.Character.ShopCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ShopCommand
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

  describe "shop 命令" do
    test "无摊位时提示" do
      p = player()
      conn = ShopCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "还没有摆摊"
    end

    # R20：货品行曾写在 `Enum.each` 里重绑局部变量，结果被丢弃，
    # 列表永远是空的（只剩一行标题 + 「共有 N 件」都没有）。
    test "有摊位时列出货品（编号、名称、价格）" do
      p = player()

      p = %{
        p
        | meta: %{p.meta | stall: "药铺", shop_stock: [%{"name" => "金创药", "price" => 100}]}
      }

      conn = ShopCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "你的摊位「药铺」当前货品："
      assert text =~ "  1. 金创药 100文"
    end

    test "摊位没有货时提示" do
      p = %{player() | meta: %{player().meta | stall: "药铺", shop_stock: []}}

      conn = ShopCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "目前没有摆上货物"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("shop")
      assert parsed.module == ShopCommand
    end
  end
end

defmodule Kantele.Character.WieldCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.WieldCommand

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
      combat_exp: 0,
      score: 0,
      potential: 0,
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

  describe "wield 命令" do
    test "身上没有武器报错" do
      p = player()
      conn = WieldCommand.wield(build_conn(p), %{"item_name" => "长剑"})
      text = output_text(conn)

      assert text =~ "你的身上没有这样东西"
    end

    test "未装备武器时卸下报错" do
      p = player()
      conn = WieldCommand.unwield(build_conn(p), %{"item_name" => "长剑"})
      text = output_text(conn)

      assert text =~ "你没有装备这样东西"
    end

    test "未穿戴护甲时卸下报错" do
      p = player()
      conn = WieldCommand.remove(build_conn(p), %{"item_name" => "铁甲"})
      text = output_text(conn)

      assert text =~ "你没有装备这样东西"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("wield 长剑")
      assert parsed.module == WieldCommand
    end
  end
end
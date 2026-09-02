defmodule Kantele.Character.DriveCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.DriveCommand
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

  describe "drive 命令" do
    test "缺少参数提示" do
      p = player()
      conn = DriveCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "你要赶什么"
    end

    test "空参数提示方向" do
      p = player()
      conn = DriveCommand.run(build_conn(p), %{"vehicle" => "", "direction" => ""})
      text = output_text(conn)

      assert text =~ "你要赶什么往哪个方向"
    end

    test "身上没有载具报错" do
      p = player()
      conn = DriveCommand.run(build_conn(p), %{"vehicle" => "马车", "direction" => "n"})
      text = output_text(conn)

      assert text =~ "这里没有这样东西让你赶"
    end

    test "drive 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("drive 马车 west")
      assert parsed.module == DriveCommand
      assert parsed.params["vehicle"] == "马车"
      assert parsed.params["direction"] == "west"
    end

    test "赶车 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("赶车 马车 west")
      assert parsed.module == DriveCommand
      assert parsed.params["vehicle"] == "马车"
    end
  end
end
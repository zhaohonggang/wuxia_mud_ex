defmodule Kantele.Character.DaubCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.DaubCommand
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

  describe "daub 命令" do
    test "缺少参数提示格式" do
      p = player()
      conn = DaubCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "指令格式：daub"
    end

    test "空参数提示格式" do
      p = player()
      conn = DaubCommand.run(build_conn(p), %{"poison" => "", "target" => ""})
      text = output_text(conn)

      assert text =~ "指令格式：daub"
    end

    test "身上没有毒药报错" do
      p = player()
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "金蛇剑"})
      text = output_text(conn)

      assert text =~ "你身上没有这样毒药"
    end
  end
end
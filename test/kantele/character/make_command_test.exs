defmodule Kantele.Character.MakeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.MakeCommand
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

  describe "make 命令" do
    test "不会制药时提示" do
      p = player()
      conn = MakeCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "你现在不会制任何药物"
    end

    test "未知药方提示" do
      p = player()
      conn = MakeCommand.run(build_conn(p), %{"arg" => "bogus"})
      text = output_text(conn)

      assert text =~ "你还不会配这种药"
    end

    test "缺少研钵提示" do
      p = player()
      conn = MakeCommand.run(build_conn(p), %{"arg" => "xiaohuandan"})
      text = output_text(conn)

      assert text =~ "先把能够磨药的研钵拿(hand)在手上"
    end

    test "make 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("make xiaohuandan")
      assert parsed.module == MakeCommand
      assert parsed.params["arg"] == "xiaohuandan"
    end
  end
end
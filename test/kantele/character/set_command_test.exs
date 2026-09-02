defmodule Kantele.Character.SetCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SetCommand
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

  describe "set 命令" do
    test "未设定任何环境变数" do
      p = player()
      conn = SetCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "你目前没有设定任何环境变数"
    end

    test "查询未设定变量" do
      p = player()
      conn = SetCommand.run(build_conn(p), %{"rest" => "time"})
      text = output_text(conn)

      assert text =~ "time 并没有设定"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("set")
      assert parsed.module == SetCommand
    end
  end
end
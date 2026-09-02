defmodule Kantele.Character.WhistleCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.WhistleCommand

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

  describe "whistle 命令" do
    test "未指明召唤对象提示" do
      p = player()
      conn = WhistleCommand.run(build_conn(p), %{"rest" => ""})
      text = output_text(conn)

      assert text =~ "你要召唤什么"
    end

    test "whistle 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("whistle hong")
      assert parsed.module == WhistleCommand
    end

    test "xiao 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("xiao hong")
      assert parsed.module == WhistleCommand
    end
  end
end
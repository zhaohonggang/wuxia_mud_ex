defmodule Kantele.Character.EatCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.EatCommand
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

  describe "eat 命令" do
    test "身上没有食物报错" do
      p = player()
      conn = EatCommand.run(build_conn(p), %{"item_name" => "包子"})
      text = output_text(conn)

      assert text =~ "你身上没有这样东西"
    end

    test "eat 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("eat 包子")
      assert parsed.module == EatCommand
    end

    test "吃 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("吃 包子")
      assert parsed.module == EatCommand
    end
  end
end
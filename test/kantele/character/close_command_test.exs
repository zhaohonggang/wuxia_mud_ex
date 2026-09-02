defmodule Kantele.Character.CloseCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.CloseCommand
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

  defp room(doors \\ %{}) do
    %{id: "test:room", doors: doors}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "close 命令" do
    test "关闭已开的门" do
      p = player()
      r = room(%{"north" => %{open: true}})
      conn = build_conn(p) |> Map.put(:room, r)
      conn = CloseCommand.run(conn, %{"target" => "north"})
      assert output_text(conn) =~ "关上了"
    end

    test "关闭不存在的门" do
      p = player()
      r = room(%{})
      conn = build_conn(p) |> Map.put(:room, r)
      conn = CloseCommand.run(conn, %{"target" => "north"})
      assert output_text(conn) =~ "你要关闭什么"
    end

    test "关闭已关的门" do
      p = player()
      r = room(%{"north" => %{open: false}})
      conn = build_conn(p) |> Map.put(:room, r)
      conn = CloseCommand.run(conn, %{"target" => "north"})
      assert output_text(conn) =~ "已经关上了"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("close north")
      assert parsed.module == CloseCommand
    end
  end
end

defmodule Kantele.Character.OpenCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.OpenCommand
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

  describe "open 命令" do
    test "打开已关的门" do
      p = player()
      r = room(%{"north" => %{open: false}})
      conn = build_conn(p) |> Map.put(:room, r)
      conn = OpenCommand.run(conn, %{"target" => "north"})
      assert output_text(conn) =~ "打开了"
    end

    test "打开不存在的门" do
      p = player()
      r = room(%{})
      conn = build_conn(p) |> Map.put(:room, r)
      conn = OpenCommand.run(conn, %{"target" => "north"})
      assert output_text(conn) =~ "你要打开什么"
    end

    test "打开已开的门" do
      p = player()
      r = room(%{"north" => %{open: true}})
      conn = build_conn(p) |> Map.put(:room, r)
      conn = OpenCommand.run(conn, %{"target" => "north"})
      assert output_text(conn) =~ "已经打开了"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("open north")
      assert parsed.module == OpenCommand
    end
  end
end

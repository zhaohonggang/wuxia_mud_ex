defmodule Kantele.Character.SpattackCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.SpattackCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20)
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        spouse: Keyword.get(opts, :spouse, nil)
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

  describe "spattack 命令" do
    test "spattack 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("spattack")
      assert parsed.module == SpattackCommand
    end

    test "无伴侣时报错" do
      p = player(spouse: nil)
      conn = SpattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "还没有伴侣"
    end

    test "有伴侣时发送思念消息" do
      p = player(spouse: %{id: "spouse-1", name: "李四"})
      conn = SpattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "李四"
      assert text =~ "心灵相通"
    end
  end
end

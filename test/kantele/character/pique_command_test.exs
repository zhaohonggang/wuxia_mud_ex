defmodule Kantele.Character.PiqueCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PiqueCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000)
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
        damage: Keyword.get(opts, :damage, %{}),
        combat: Keyword.get(opts, :combat, Combat.new())
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

  describe "路由解析" do
    test "pique 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("pique")
      assert parsed.module == PiqueCommand
    end

    test "jianu 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("jianu")
      assert parsed.module == PiqueCommand
    end
  end

  describe "pique 命令" do
    test "设置 none 放弃愤怒" do
      p = player(damage: %{jianu: 50})
      conn = PiqueCommand.run(build_conn(p), %{"arg" => "none"})
      assert output_text(conn) =~ "放弃"
    end

    test "正常设置愤怒值" do
      p = player(damage: %{max_craze: 1000})
      conn = PiqueCommand.run(build_conn(p), %{"arg" => "50"})
      assert output_text(conn) =~ "50"
    end
  end
end

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

  describe "路由解析" do
    test "spattack 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("spattack")
      assert parsed.module == SpattackCommand
    end
  end

  describe "spattack 命令" do
    test "无伴侣时拒绝" do
      p = player(spouse: nil)
      conn = SpattackCommand.run(build_conn(p), %{"arg" => ""})
      assert conn.output != []
    end

    test "有伴侣时可用" do
      p = player(spouse: %{id: "spouse-1", name: "李四"})
      conn = SpattackCommand.run(build_conn(p), %{"arg" => ""})
      assert conn.output != []
    end
  end
end

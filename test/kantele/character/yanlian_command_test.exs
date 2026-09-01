defmodule Kantele.Character.YanlianCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.YanlianCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      qi: Keyword.get(opts, :qi, 5000)
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
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  describe "路由解析" do
    test "yanlian 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("yanlian")
      assert parsed.module == YanlianCommand
    end
  end

  describe "yanlian 命令" do
    test "无技能名时提示" do
      p = player()
      conn = YanlianCommand.run(build_conn(p), %{"arg" => ""})
      assert conn.output != []
    end
  end
end

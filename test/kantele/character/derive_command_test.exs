defmodule Kantele.Character.DeriveCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.DeriveCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      max_jing: Keyword.get(opts, :max_jing, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      combat_exp: Keyword.get(opts, :combat_exp, 50000)
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
    test "derive 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("derive")
      assert parsed.module == DeriveCommand
    end
  end

  describe "derive 命令" do
    test "实战经验不足时拒绝" do
      p = player(combat_exp: 10000)
      conn = DeriveCommand.run(build_conn(p), %{})
      assert conn.output != []
    end

    test "体力不足时拒绝" do
      p = player(qi: 1000, max_qi: 5000)
      conn = DeriveCommand.run(build_conn(p), %{})
      assert conn.output != []
    end
  end
end

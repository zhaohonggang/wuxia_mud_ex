defmodule Kantele.Character.FuseCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.FuseCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      neili: Keyword.get(opts, :neili, 5000),
      max_neili: Keyword.get(opts, :max_neili, 6000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{"force" => 350})
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
    test "fuse 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("fuse")
      assert parsed.module == FuseCommand
    end
  end

  describe "fuse 命令" do
    test "无物品时提示" do
      p = player()
      conn = FuseCommand.run(build_conn(p), %{"arg" => ""})
      assert conn.output != []
    end

    test "内力不足时拒绝" do
      p = player(neili: 1000)
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      assert conn.output != []
    end
  end
end

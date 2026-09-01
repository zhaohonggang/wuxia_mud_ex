defmodule Kantele.Character.SynCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.SynCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000),
      neili: Keyword.get(opts, :neili, 5000),
      max_neili: Keyword.get(opts, :max_neili, 6000)
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
        stats: stats
      }
    }
  end

  describe "路由解析" do
    test "syn 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("syn")
      assert parsed.module == SynCommand
    end
  end

  describe "syn 命令" do
    test "内力不足时拒绝" do
      p = player(neili: 1000, max_neili: 5000)
      conn = SynCommand.run(build_conn(p), %{"arg" => "item"})
      assert conn.output != []
    end

    test "气血不足时拒绝" do
      p = player(qi: 1000, max_qi: 5000)
      conn = SynCommand.run(build_conn(p), %{"arg" => "item"})
      assert conn.output != []
    end
  end
end

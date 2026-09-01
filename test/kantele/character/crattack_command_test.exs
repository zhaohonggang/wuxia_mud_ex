defmodule Kantele.Character.CrattackCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.CrattackCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
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

  describe "路由解析" do
    test "crattack 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("crattack")
      assert parsed.module == CrattackCommand
    end
  end

  describe "crattack 命令" do
    test "愤怒值不足时拒绝" do
      p = player(damage: %{craze: 300})
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      assert conn.output != []
    end

    test "愤怒值不够必杀时拒绝" do
      p = player(damage: %{craze: 800})
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      assert conn.output != []
    end
  end
end

defmodule Kantele.Character.AnimaoutCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AnimaoutCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      max_jing: Keyword.get(opts, :max_jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      max_jingli: Keyword.get(opts, :max_jingli, 3000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      potential: Keyword.get(opts, :potential, 5000),
      learned_points: Keyword.get(opts, :learned_points, 1000)
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
    test "animaout 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("animaout")
      assert parsed.module == AnimaoutCommand
    end
  end

  describe "animaout 命令" do
    test "精力不足时拒绝" do
      p = player(jingli: 500, max_jingli: 3000)
      conn = AnimaoutCommand.run(build_conn(p), %{})
      assert conn.output != []
    end

    test "潜能不够时拒绝" do
      p = player(potential: 500, learned_points: 0)
      conn = AnimaoutCommand.run(build_conn(p), %{})
      assert conn.output != []
    end
  end
end

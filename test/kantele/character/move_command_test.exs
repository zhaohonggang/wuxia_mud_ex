defmodule Kantele.Character.MoveCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.MoveCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
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

  defp movement_events(conn) do
    Enum.filter(conn.events, fn event ->
      event.topic == Kalevala.Event.Movement.Request
    end)
  end

  describe "move 命令" do
    test "north 发送移动请求" do
      p = player()
      conn = MoveCommand.north(build_conn(p), %{})
      events = movement_events(conn)

      assert length(events) == 1
      assert hd(events).data.exit_name == "north"
    end

    test "south 发送移动请求" do
      p = player()
      conn = MoveCommand.south(build_conn(p), %{})
      assert hd(movement_events(conn)).data.exit_name == "south"
    end

    test "north 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("north")
      assert parsed.module == MoveCommand
      assert parsed.function == :north
    end

    test "n 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("n")
      assert parsed.module == MoveCommand
      assert parsed.function == :north
    end
  end
end
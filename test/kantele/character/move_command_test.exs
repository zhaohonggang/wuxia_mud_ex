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

  describe "方向首字母/全词不误吞其他命令（A8）" do
    for {input, dir} <- [
          {"say", :south},
          {"station", :south},
          {"sell", :south},
          {"suicide", :south},
          {"eat", :east},
          {"enable", :east},
          {"nick", :north},
          {"news", :north},
          {"wield", :west},
          {"wash", :west},
          {"unset", :up},
          {"update", :up},
          {"daub", :down},
          {"drink", :down},
          {"northwest", :north},
          {"southeast", :south}
        ] do
      test "`#{input}` 不被误解析为 #{dir}" do
        refute match?(
                 {:ok, %{module: MoveCommand, function: unquote(dir)}},
                 Kantele.Character.Commands.parse(unquote(input))
               )
      end
    end

    test "say 带参解析到 SayCommand" do
      {:ok, parsed} = Kantele.Character.Commands.parse("say 你好")
      assert parsed.module == Kantele.Character.SayCommand
    end

    for {input, dir} <- [{"s", :south}, {"e", :east}, {"w", :west}, {"u", :up}, {"d", :down}] do
      test "`#{input}` 别名仍解析为 #{dir}" do
        {:ok, parsed} = Kantele.Character.Commands.parse(unquote(input))
        assert parsed.module == MoveCommand
        assert parsed.function == unquote(dir)
      end
    end
  end
end
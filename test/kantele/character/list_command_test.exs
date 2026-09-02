defmodule Kantele.Character.ListCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ListCommand
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

  defp shop_events(conn) do
    Enum.filter(conn.events, fn event -> event.topic == "shop/list" end)
  end

  describe "list 命令" do
    test "指定商人发出 shop/list 事件" do
      p = player()
      conn = ListCommand.run(build_conn(p), %{"name" => "王老板"})
      events = shop_events(conn)

      assert length(events) == 1
      assert hd(events).data.name == "王老板"
    end

    test "list 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("list 王老板")
      assert parsed.module == ListCommand
      assert parsed.params["name"] == "王老板"
    end
  end
end
defmodule Kantele.Character.AskCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AskCommand
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

  defp ask_events(conn) do
    Enum.filter(conn.events, fn event -> event.topic == "characters/ask" end)
  end

  describe "ask 命令" do
    test "问询发出 characters/ask 事件" do
      p = player()
      conn = AskCommand.run(build_conn(p), %{"name" => "王老板", "keyword" => "客栈"})
      event = hd(ask_events(conn))

      assert event.data.name == "王老板"
      assert event.data.keyword == "客栈"
    end

    test "剥离 about 前缀" do
      p = player()
      conn = AskCommand.run(build_conn(p), %{"name" => "王老板", "keyword" => "about 客栈"})
      event = hd(ask_events(conn))

      assert event.data.keyword == "客栈"
    end

    test "ask 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("ask 王老板 about 客栈")
      assert parsed.module == AskCommand
      assert parsed.params["name"] == "王老板"
    end

    test "问 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("问 王老板 about 客栈")
      assert parsed.module == AskCommand
    end
  end
end
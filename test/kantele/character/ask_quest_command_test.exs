defmodule Kantele.Character.AskQuestCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AskQuestCommand
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

  defp quest_events(conn) do
    Enum.filter(conn.events, fn event -> event.topic == "quest/ask" end)
  end

  describe "ask_quest 命令" do
    test "请求任务发出 quest/ask 事件" do
      p = player()
      conn = AskQuestCommand.run(build_conn(p), %{"name" => "王重九"})
      event = hd(quest_events(conn))

      assert event.data.name == "王重九"
    end

    test "ask_quest 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("ask_quest 王重九")
      assert parsed.module == AskQuestCommand
      assert parsed.params["name"] == "王重九"
    end

    test "问任务 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("问任务 王重九")
      assert parsed.module == AskQuestCommand
    end
  end
end
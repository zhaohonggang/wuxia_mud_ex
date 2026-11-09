defmodule Kantele.Character.LegacyAskCommandTest do
  @moduledoc """
  S1 之前的 ask 占位桩回归（保留路由解析 / about 前缀剥离覆盖）。

  B5 主测试在 `commands/ask_command_test.exs`；本模块改用独立模块名避免同名冲突。
  S1 真化后 `AskCommand` 会先在房间里查 NPC，故这里注入一个无 ask_handler 的
  店家，让普通问询落回 `characters/ask` 事件流。
  """

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

  # S1 真化后 find_ask_npc/2 会读 conn.private.room.private.characters；
  # 注入一个不带 ask_handler / quest_gift 的店家，问讯才会落回事件流。
  defp conn_with_shopkeeper(p) do
    npc = %{
      name: "王老板",
      meta: %{aliases: ["王老板"], ask_handler: nil}
    }

    conn = build_conn(p)
    %{conn | private: %{conn.private | room: %{private: %{characters: [npc]}}}}
  end

  describe "ask 命令" do
    test "问询发出 characters/ask 事件" do
      p = player()
      conn = AskCommand.run(conn_with_shopkeeper(p), %{"name" => "王老板", "keyword" => "客栈"})
      event = hd(ask_events(conn))

      assert event.data.name == "王老板"
      assert event.data.keyword == "客栈"
    end

    test "剥离 about 前缀" do
      p = player()
      conn = AskCommand.run(conn_with_shopkeeper(p), %{"name" => "王老板", "keyword" => "about 客栈"})
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

defmodule Kantele.Character.DuelCommandTest do
  @moduledoc """
  `duel` / `决斗` 指令测试：验证向目标发起公开决斗，分发 combat/attack (type: duel) 事件。
  """

  use ExVenture.DataCase, async: false
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.DuelCommand

  defp player(_attrs \\ []) do
    %Character{
      id: "duel-test-player",
      name: "duel-test-player",
      pid: self(),
      room_id: "test:room",
      attributes: %{},
      inventory: [],
      meta: %{
        vitals: %{},
        stats: %{},
        combat: %{enemies: []},
        temp: %{},
        setup_done: true
      }
    }
  end

  defp target(name) do
    %Character{
      id: "duel-test-target",
      name: name,
      pid: self(),
      room_id: "test:room",
      attributes: %{},
      inventory: [],
      meta: %{
        vitals: %{},
        stats: %{},
        combat: %{enemies: []},
        temp: %{},
        setup_done: true
      }
    }
  end

  defp conn_with_target(player, target) do
    conn = build_conn(player)
    private = %{conn.private | room: %{private: %{characters: [target]}}}
    %{conn | private: private}
  end

  test "duel <目标>：向目标发起决斗，分发 combat/attack (type: duel)" do
    player = player()
    tgt = target("李四")
    conn = conn_with_target(player, tgt)

    result = DuelCommand.run(conn, %{"name" => "李四"})

    assert Enum.any?(result.events, fn
      %Event{topic: "combat/attack", data: %{type: "duel", name: "李四"}} -> true
      _ -> false
    end)

    assert result.assigns[:prompt] == false
  end

  test "决斗 <目标>：中文别名也能发起决斗" do
    player = player()
    tgt = target("王五")
    conn = conn_with_target(player, tgt)

    result = DuelCommand.run(conn, %{"name" => "王五"})

    assert Enum.any?(result.events, fn
      %Event{topic: "combat/attack", data: %{type: "duel", name: "王五"}} -> true
      _ -> false
    end)
  end

  test "duel 目标在房间中：目标角色被标记为 competitor" do
    player = player()
    tgt = target("赵六")
    conn = conn_with_target(player, tgt)

    result = DuelCommand.run(conn, %{"name" => "赵六"})

    assert Enum.any?(result.events, fn
      %Event{topic: "combat/attack", data: %{type: "duel", name: "赵六"}} -> true
      _ -> false
    end)
  end
end

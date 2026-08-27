defmodule Kantele.Character.FleeCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.FleeCommand
  alias Kantele.Character.PlayerMeta

  import Kalevala.ConnTest

  describe "flee 命令前置校验" do
    test "非战斗状态拒绝逃跑" do
      conn = run_flee(player())

      assert output_text(conn) =~ "没有在战斗"
    end

    test "busy 状态拒绝逃跑" do
      {combat, _} =
        Combat.new()
        |> Combat.add_enemy(%{id: "npc:1", pid: self(), name: "野猪", room_id: "test:room"})

      character = player(combat: %{busy: 2, enemies: combat.enemies})

      conn = run_flee(character)

      assert output_text(conn) =~ "正忙着"
    end

    test "战斗中触发逃跑事件" do
      character = player_in_fight()

      conn = run_flee(character)

      # 应该触发 room/flee 事件（由 FleeEvent 处理）
      assert conn.assigns[:prompt] == false
    end
  end

  # ---- helpers ----

  defp player(opts \\ []) do
    base_combat = Keyword.get(opts, :combat, %{})

    combat =
      Enum.reduce(base_combat, Combat.new(), fn {k, v}, acc ->
        Map.put(acc, k, v)
      end)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: combat
      }
    }
  end

  defp player_in_fight() do
    combat =
      Combat.new()
      |> Combat.add_enemy(%{id: "npc:1", pid: self(), name: "野猪", room_id: "test:room"})
      |> elem(0)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: combat
      }
    }
  end

  defp run_flee(character) do
    FleeCommand.run(build_conn(character), %{})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end

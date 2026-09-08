defmodule Kantele.Character.WhorideCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Presence
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.WhorideCommand

  defp player(attrs \\ %{}) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      attributes: Map.get(attrs, :attributes, %{}),
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "普通玩家无权限" do
    conn = WhorideCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "没有巫师的权限"
  end

  test "巫师查看无人骑乘" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = WhorideCommand.run(build_conn(wizard), %{})
    assert output_text(conn) =~ "没有人在骑乘"
  end

  test "巫师查看在线骑乘者" do
    tracker = spawn(fn -> Process.sleep(:infinity) end)

    rider = %Kalevala.Character{
      id: "rider-1",
      name: "李四",
      pid: tracker,
      room_id: "test:room",
      attributes: %{},
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        riding: %{instance_id: "mount-1", item_id: "global:horse", name: "枣红马"}
      }
    }

    :ok = Presence.track(rider)
    on_exit(fn -> Process.exit(tracker, :kill) end)

    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = WhorideCommand.run(build_conn(wizard), %{})
    text = output_text(conn)

    assert text =~ "当前骑乘状态"
    assert text =~ "李四(rider-1) 骑在 枣红马 上"
  end
end

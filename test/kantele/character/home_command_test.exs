defmodule Kantele.Character.HomeCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.HomeCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.Zone
  alias Kantele.World.ZoneCache

  defp player(room_id, wiz?) do
    attributes = if wiz?, do: %{"wiz_level" => 1}, else: %{}

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: room_id,
      attributes: attributes,
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

  describe "home 传送" do
    setup do
      zone = %Zone{
        id: "liuxi",
        rooms: [
          %Room{id: "liuxi:start", key: "start", flags: ["startroom"], y: 0, x: 0, z: 0, exits: []},
          %Room{id: "liuxi:field", key: "field", flags: [], y: 1, x: 0, z: 0, exits: []}
        ]
      }

      ZoneCache.cache(zone)
      :ok
    end

    test "普通玩家无权限" do
      conn = HomeCommand.run(build_conn(player("liuxi:field", false)), %{})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "巫师传送到起始房间" do
      conn = HomeCommand.run(build_conn(player("liuxi:field", true)), %{})

      updated = conn.private.update_character || conn.character
      assert updated.room_id == "liuxi:start"
      assert Enum.any?(conn.events, &(&1.topic == Kalevala.Event.Movement))
    end

    test "已身处起始房间时提示" do
      conn = HomeCommand.run(build_conn(player("liuxi:start", true)), %{})
      assert output_text(conn) =~ "已经在起始之地"
    end
  end

  describe "区域不可用时" do
    test "巫师在未知区域无法使用 home" do
      conn = HomeCommand.run(build_conn(player("unknown:room", true)), %{})
      assert output_text(conn) =~ "无法使用 home"
    end
  end
end
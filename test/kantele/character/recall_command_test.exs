defmodule Kantele.Character.RecallCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.RecallCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.Zone
  alias Kantele.World.ZoneCache

  defp player(room_id) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: room_id,
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

  describe "回城目标解析" do
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

    test "回城到带 startroom flag 的房间" do
      conn = RecallCommand.run(build_conn(player("liuxi:field")), %{})

      assert output_text(conn) == ""
      # 触发了两段 Movement（from/to）+ room/look
      assert Enum.any?(conn.events, &(&1.topic == Kalevala.Event.Movement))
    end

    test "已身处起始房间时提示" do
      conn = RecallCommand.run(build_conn(player("liuxi:start")), %{})

      assert output_text(conn) =~ "已经在起始之地"
    end
  end

  describe "区域不可用时" do
    test "未知区域提示无法回城" do
      conn = RecallCommand.run(build_conn(player("unknown:room")), %{})

      assert output_text(conn) =~ "无法使用 recall"
    end
  end
end

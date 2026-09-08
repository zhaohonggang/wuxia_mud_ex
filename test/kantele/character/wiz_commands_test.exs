defmodule Kantele.Character.WizCommandsTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.LocalcmdsCommand
  alias Kantele.Character.MemCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Presence
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Who2Command
  alias Kantele.Character.Who3Command
  alias Kantele.Character.WhoamiCommand
  alias Kantele.World.Room
  alias Kantele.World.Zone
  alias Kantele.World.ZoneCache

  defp player(attrs \\ %{}) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: Map.get(attrs, :room_id, "test:room"),
      attributes: Map.get(attrs, :attributes, %{}),
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp wizard, do: player(%{attributes: %{"wiz_level" => 1}})

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "whoami" do
    test "普通玩家无权限" do
      conn = WhoamiCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "巫师显示 User ID" do
      conn = WhoamiCommand.run(build_conn(wizard()), %{})
      text = output_text(conn)

      assert text =~ "User ID = 张三"
      assert text =~ "Effective User ID = 张三"
    end
  end

  describe "mem" do
    test "普通玩家无权限" do
      conn = MemCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "巫师显示内存占用" do
      conn = MemCommand.run(build_conn(wizard()), %{})
      assert output_text(conn) =~ "共使用了" and output_text(conn) =~ "内存"
    end
  end

  describe "localcmds" do
    setup do
      zone = %Zone{
        id: "liuxi",
        rooms: [
          %Room{
            id: "liuxi:start",
            key: "start",
            flags: [],
            y: 0,
            x: 0,
            z: 0,
            exits: [
              %Kalevala.World.Exit{
                id: "liuxi:start:north",
                exit_name: "north",
                start_room_id: "liuxi:start",
                end_room_id: "liuxi:field"
              }
            ]
          },
          %Room{id: "liuxi:field", key: "field", flags: [], y: 1, x: 0, z: 0, exits: []}
        ]
      }

      ZoneCache.cache(zone)
      :ok
    end

    test "普通玩家无权限" do
      conn = LocalcmdsCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "巫师列出房间出口" do
      p = wizard() |> Map.put(:room_id, "liuxi:start")

      conn = LocalcmdsCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "提供以下指令"
      assert text =~ "north"
      assert text =~ "前往北方"
    end

    test "无出口房间提示没有任何本地指令" do
      p = player(%{attributes: %{"wiz_level" => 1}, room_id: "liuxi:field"})
      conn = LocalcmdsCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "没有任何可用的本地指令"
    end
  end

  describe "who2" do
    test "普通玩家无权限" do
      conn = Who2Command.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "巫师列出在线角色并按权限排序" do
      track_char("李四", 2)
      track_char("张三", 0)

      conn = Who2Command.run(build_conn(wizard()), %{})
      text = output_text(conn)

      assert text =~ "在线角色查询"
      assert text =~ ~r/共有 \d+ 位使用者连线中/
      assert text =~ "巫师2"
      assert text =~ "玩家"
      assert index_of(text, "巫师2") < index_of(text, "玩家")
    end
  end

  describe "who3" do
    test "普通玩家无权限" do
      conn = Who3Command.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "巫师列出玩家六维属性" do
      track_char("王五", 1)

      conn = Who3Command.run(build_conn(wizard()), %{})
      text = output_text(conn)

      assert text =~ "玩家属性查询"
      assert text =~ "悟性  根骨  身法  膂力  容貌"
      assert text =~ "王五"
      assert text =~ "[W1]"
    end
  end

  defp index_of(text, sub) do
    case :binary.match(text, sub) do
      {pos, _len} -> pos
      :nomatch -> -1
    end
  end

  defp track_char(name, wiz_level) do
    pid = spawn(fn -> Process.sleep(:infinity) end)

    character = %Kalevala.Character{
      id: "char-#{name}",
      name: name,
      pid: pid,
      room_id: "test:room",
      attributes: %{"wiz_level" => wiz_level},
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: struct(Stats.new(), int: 30, con: 30, dex: 30, str: 30),
        combat: Kantele.Character.Combat.new()
      }
    }

    :ok = Presence.track(character)
    on_exit(fn -> Process.exit(pid, :kill) end)
  end
end
defmodule Kantele.Character.WizardGuardTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.CloneCommand
  alias Kantele.Character.DestCommand
  alias Kantele.Character.GotoCommand
  alias Kantele.Character.MudinfoCommand
  alias Kantele.Character.Presence
  alias Kantele.Character.SummonCommand
  alias Kantele.Character.UpdateCommand
  alias Kantele.Character.UptimeCommand
  alias Kantele.Character.WhereCommand
  alias Kantele.Character.Who1Command

  defp player(attrs \\ %{}) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "start:room",
      attributes: Map.get(attrs, :attributes, %{}),
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp tracked_player(name, id) do
    tracker = spawn(fn -> Process.sleep(:infinity) end)

    tracked = %Kalevala.Character{
      id: id,
      name: name,
      pid: tracker,
      room_id: "zone:room",
      attributes: %{"wiz_level" => 0},
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }

    :ok = Presence.track(tracked)
    on_exit(fn -> Process.exit(tracker, :kill) end)

    tracked
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated(conn), do: conn.private.update_character || conn.character

  test "goto 普通玩家被拦截，不会瞬移" do
    conn = GotoCommand.run(build_conn(player()), %{"target" => "zone:room"})
    text = output_text(conn)

    assert text =~ "没有巫师的权限"
    assert updated(conn).room_id == "start:room"
  end

  test "goto 巫师可瞬移到房间" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = GotoCommand.run(build_conn(wizard), %{"target" => "zone:room"})

    assert updated(conn).room_id == "zone:room"
  end

  test "goto 巫师瞬移到在线玩家所在房间" do
    tracked_player("李四", "target-1")
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = GotoCommand.run(build_conn(wizard), %{"target" => "李四"})

    assert updated(conn).room_id == "zone:room"
  end

  test "where 普通玩家被拦截" do
    tracked_player("李四", "target-1")
    conn = WhereCommand.run(build_conn(player()), %{})

    text = output_text(conn)
    assert text =~ "没有巫师的权限"
    refute text =~ "李四"
  end

  test "where 巫师列出在线角色位置" do
    tracked_player("李四", "target-1")
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = WhereCommand.run(build_conn(wizard), %{})

    text = output_text(conn)
    assert text =~ "在线角色位置"
    assert text =~ "zone:room : 李四(target-1)"
  end

  test "who1 普通玩家被拦截" do
    tracked_player("李四", "target-1")
    conn = Who1Command.run(build_conn(player()), %{})

    text = output_text(conn)
    assert text =~ "没有巫师的权限"
    refute text =~ "李四"
  end

  test "who1 巫师列出在线角色" do
    tracked_player("李四", "target-1")
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = Who1Command.run(build_conn(wizard), %{})

    text = output_text(conn)
    assert text =~ "在线角色 (巫师模式)"
    assert text =~ "李四 - zone:room"
    assert text =~ "共 1 人"
  end

  test "clone 普通玩家被拦截" do
    conn = CloneCommand.run(build_conn(player()), %{"target" => "sword"})
    assert output_text(conn) =~ "没有巫师的权限"
  end

  test "clone 巫师指定生物时提示未实现" do
    tracked_player("李四", "target-1")
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = CloneCommand.run(build_conn(wizard), %{"target" => "李四"})
    assert output_text(conn) =~ "生物克隆暂未实现"
  end

  test "clone 巫师指定未知目标" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = CloneCommand.run(build_conn(wizard), %{"target" => "不存在的物品"})
    assert output_text(conn) =~ "找不到"
  end

  test "dest 普通玩家被拦截" do
    conn = DestCommand.run(build_conn(player()), %{"target" => "sword"})
    assert output_text(conn) =~ "没有巫师的权限"
  end

  test "dest 巫师删除对象" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = DestCommand.run(build_conn(wizard), %{"target" => "sword"})
    assert output_text(conn) =~ "对象 sword 已被删除"
  end

  test "update 普通玩家被拦截" do
    conn = UpdateCommand.run(build_conn(player()), %{"target" => "sword"})
    assert output_text(conn) =~ "没有巫师的权限"
  end

  test "update 巫师重载对象" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = UpdateCommand.run(build_conn(wizard), %{"target" => "sword"})
    assert output_text(conn) =~ "对象 sword 已重新加载"
  end

  test "uptime 显示运行时间" do
    conn = UptimeCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "武林外传已经运行"
  end

  test "mudinfo 显示系统资讯" do
    conn = MudinfoCommand.run(build_conn(player()), %{})
    text = output_text(conn)

    assert text =~ "Mud 中文名称"
    assert text =~ "线上玩家数量"
  end

  test "summon 幽灵不能召唤" do
    conn = SummonCommand.run(build_conn(player(%{attributes: %{"ghost" => true}})), %{"item" => "x"})
    assert output_text(conn) =~ "等你还了阳再召唤吧"
  end

  test "summon 未登记物品提示不知如何召唤" do
    conn = SummonCommand.run(build_conn(player()), %{"item" => "x"})
    assert output_text(conn) =~ "你不知道如何召唤"
  end

  test "summon 无参数列出可召唤物品" do
    conn = SummonCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "你现在可以召唤的物品有"
  end
end
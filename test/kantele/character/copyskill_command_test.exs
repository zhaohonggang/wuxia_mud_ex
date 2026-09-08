defmodule Kantele.Character.CopyskillCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CopyskillCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Presence
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

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
        combat: Combat.new()
      }
    }
  end

  defp source_player do
    stats = %{
      Stats.new()
      | skills: %{"sword" => 100, "dodge" => 80},
        mapped: %{"sword" => "liuxin-jian"},
        performs: MapSet.new(["liuxin-jian/liu"]),
        combat_exp: 50_000,
        str: 99,
        dex: 88,
        con: 77,
        int: 66
    }

    tracker = spawn(fn -> Process.sleep(:infinity) end)

    source = %Kalevala.Character{
      id: "source-1",
      name: "李四",
      pid: tracker,
      room_id: "test:room",
      attributes: %{},
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: %{Combat.new() | jiali: 30}
      }
    }

    :ok = Presence.track(source)
    on_exit(fn -> Process.exit(tracker, :kill) end)

    source
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp update_character(conn), do: conn.private.update_character || conn.character

  test "普通玩家无权限" do
    conn = CopyskillCommand.run(build_conn(player()), %{"arg" => "某玩家"})
    assert output_text(conn) =~ "没有巫师的权限"
  end

  test "未指定目标" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = CopyskillCommand.run(build_conn(wizard), %{"arg" => nil})
    assert output_text(conn) =~ "这里没有这位玩家"
  end

  test "目标不在线" do
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = CopyskillCommand.run(build_conn(wizard), %{"arg" => "不存在的人"})
    assert output_text(conn) =~ "这里没有这位玩家"
  end

  test "巫师复制在线玩家的武功到自身" do
    source_player()
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = CopyskillCommand.run(build_conn(wizard), %{"arg" => "李四"})

    text = output_text(conn)
    assert text =~ "学会了 李四 的武功"

    stats = update_character(conn).meta.stats
    assert stats.skills == %{"sword" => 100, "dodge" => 80}
    assert stats.mapped == %{"sword" => "liuxin-jian"}
    assert stats.performs == MapSet.new(["liuxin-jian/liu"])
    assert stats.combat_exp == 50_000
    assert stats.str == 99
    assert stats.dex == 88
    assert stats.con == 77
    assert stats.int == 66
    assert update_character(conn).meta.combat.jiali == 30
  end

  test "复制会替换自身原有武功" do
    source_player()
    wizard = player(%{attributes: %{"wiz_level" => 1}})
    conn = CopyskillCommand.run(build_conn(wizard), %{"arg" => "李四"})

    stats = update_character(conn).meta.stats
    assert Map.get(stats.skills, "unarmed", nil) == nil
    assert stats.performs == MapSet.new(["liuxin-jian/liu"])
  end
end
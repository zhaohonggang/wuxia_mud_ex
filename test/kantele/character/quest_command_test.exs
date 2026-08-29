defmodule Kantele.Character.QuestCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.QuestCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Quest

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        quests: Quest.new()
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

  test "无任务显示空提示" do
    conn = QuestCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "没有任何任务记录"
  end

  test "显示已完成任务" do
    spec = %{file: "song-yupai", kill: ["黑虎"], item: ["玉牌"]}
    {:ok, q} = Quest.set_solved(player().meta.quests, spec)

    p = %{player() | meta: PlayerMeta.put_quests(player().meta, q)}
    conn = QuestCommand.run(build_conn(p), %{})

    assert output_text(conn) =~ "已完成任务（1）"
    assert output_text(conn) =~ "song-yupai"
  end

  test "显示在办任务及击杀/收集进度" do
    q = Quest.new()
    {:ok, q} = Quest.set_todo(q, %{file: "q1", kill: ["黑虎", "野狼"], item: ["玉牌"]})
    {:ok, q} = Quest.add_killed(q, %{file: "q1", kill: ["黑虎", "野狼"]}, "黑虎", 2)
    {:ok, q} = Quest.add_item(q, %{file: "q1", kill: [], item: ["玉牌"]}, "玉牌", 1)

    p = %{player() | meta: PlayerMeta.put_quests(player().meta, q)}
    conn = QuestCommand.run(build_conn(p), %{})

    assert output_text(conn) =~ "在办任务（1）"
    assert output_text(conn) =~ "黑虎 x2"
    assert output_text(conn) =~ "玉牌 x1"
    # 计数为 0 的不显示
    refute output_text(conn) =~ "野狼"
  end

  test "quest 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("quest")
    assert parsed.module == Kantele.Character.QuestCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("任务")
    assert parsed.module == Kantele.Character.QuestCommand
  end
end
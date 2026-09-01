defmodule Kantele.Character.Quest2CommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Quest2Command
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

  defp quest_player(q) do
    %{player() | meta: PlayerMeta.put_quests(player().meta, q)}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_meta(conn), do: (conn.private.update_character || conn.character).meta

  test "无任务列出空提示" do
    conn = Quest2Command.run(build_conn(player()), %{})
    assert output_text(conn) =~ "你目前没有接受任何任务"
  end

  test "列出在办任务" do
    {:ok, q} = Quest.set_todo(Quest.new(), %{file: "q1", kill: ["黑虎"]})
    {:ok, q} = Quest.set_todo(q, %{file: "q2", kill: ["野狼"]})
    conn = Quest2Command.run(build_conn(quest_player(q)), %{})

    assert output_text(conn) =~ "任务日志"
    assert output_text(conn) =~ "q1"
    assert output_text(conn) =~ "q2"
  end

  test "显示任务细节及击杀/收集进度" do
    {:ok, q} = Quest.set_todo(Quest.new(), %{file: "q1", kill: ["黑虎", "野狼"], item: ["玉牌"]})
    {:ok, q} = Quest.add_killed(q, %{file: "q1", kill: ["黑虎", "野狼"]}, "黑虎", 2)

    conn = Quest2Command.run(build_conn(quest_player(q)), %{"arg" => "1"})

    assert output_text(conn) =~ "任务：q1"
    assert output_text(conn) =~ "黑虎： 2"
    # 计数为 0 的不显示
    refute output_text(conn) =~ "野狼"
  end

  test "放弃任务" do
    {:ok, q} = Quest.set_todo(Quest.new(), %{file: "q1", kill: ["黑虎"]})
    {:ok, q} = Quest.set_todo(q, %{file: "q2", kill: []})

    conn = Quest2Command.run(build_conn(quest_player(q)), %{"arg" => "2 -d"})

    assert output_text(conn) =~ "你放弃了 q2"
    assert Quest.get_todo_list(updated_meta(conn).quests) |> Map.has_key?("q1")
    refute Quest.get_todo_list(updated_meta(conn).quests) |> Map.has_key?("q2")
  end

  test "列出已解决任务" do
    {:ok, q} = Quest.set_solved(Quest.new(), %{file: "q1"})
    {:ok, q} = Quest.set_solved(q, %{file: "q2"})

    conn = Quest2Command.run(build_conn(quest_player(q)), %{"arg" => "-s"})

    assert output_text(conn) =~ "已完成的任务列表"
    assert output_text(conn) =~ "q1"
    assert output_text(conn) =~ "q2"
  end

  test "quest2 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("quest2")
    assert parsed.module == Kantele.Character.Quest2Command

    {:ok, parsed} = Kantele.Character.Commands.parse("任务日志")
    assert parsed.module == Kantele.Character.Quest2Command
  end
end

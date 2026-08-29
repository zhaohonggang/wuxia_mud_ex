defmodule Kantele.Character.NoteCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.NoteCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
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

  test "逐行累积并用 . 结束输出便笺" do
    conn = build_conn(player())
    conn = NoteCommand.run(conn, %{"rest" => "第一行"})
    conn = NoteCommand.run(conn, %{"rest" => "第二行"})
    conn = NoteCommand.run(conn, %{"rest" => "."})

    assert output_text(conn) =~ "便笺完成"
    assert output_text(conn) =~ "第一行"
    assert output_text(conn) =~ "第二行"
    # 会话已清空
    assert PlayerMeta.get_temp(conn.character.meta, "note_session", nil) == nil
  end

  test "~q 取消并弃稿" do
    conn = build_conn(player())
    conn = NoteCommand.run(conn, %{"rest" => "写一半"})
    conn = NoteCommand.run(conn, %{"rest" => "~q"})

    assert output_text(conn) =~ "丢弃"
    assert PlayerMeta.get_temp(conn.character.meta, "note_session", nil) == nil
  end

  test "note 路由解析（带正文，note 单字被 north 的 n 前缀吞并）" do
    {:ok, parsed} = Kantele.Character.Commands.parse("note 第一行")
    assert parsed.module == Kantele.Character.NoteCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("便笺 第一行")
    assert parsed.module == Kantele.Character.NoteCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("笔记 第一行")
    assert parsed.module == Kantele.Character.NoteCommand
  end
end
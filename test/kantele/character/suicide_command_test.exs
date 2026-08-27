defmodule Kantele.Character.SuicideCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.SuicideCommand
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

  test "无参数警告（不删除）" do
    conn = SuicideCommand.run(build_conn(player()), %{"rest" => ""})
    text = output_text(conn)
    assert text =~ "永远删除"
    assert text =~ "占位实现"
    refute conn.private.halt?
  end

  test "无参数警示完整自杀指令" do
    conn = SuicideCommand.run(build_conn(player()), %{"rest" => "abc"})
    assert output_text(conn) =~ "suicide -f"
  end

  test "suicide -f 道别并停机（stub 仍保留档案）" do
    conn = SuicideCommand.run(build_conn(player()), %{"rest" => "-f"})
    assert output_text(conn) =~ "永别了"
    assert conn.private.halt?
    assert conn.assigns[:prompt] == false
  end

  test "suicide 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("suicide -f")
    assert parsed.module == Kantele.Character.SuicideCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("自杀 -f")
    assert parsed.module == Kantele.Character.SuicideCommand
  end
end

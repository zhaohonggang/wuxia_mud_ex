defmodule Kantele.Character.SchemeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SchemeCommand
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

  defp updated_meta(conn), do: (conn.private.update_character || conn.character).meta

  test "无计划时提示" do
    conn = SchemeCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "并没有制订任何计划"
  end

  test "制订新计划并落盘" do
    conn = SchemeCommand.run(build_conn(player()), %{"arg" => "读书 十分钟"})
    assert output_text(conn) =~ "设置了一份新的计划"
    assert updated_meta(conn).schedule == "读书 十分钟"
  end

  test "edit 别名制订计划" do
    conn = SchemeCommand.run(build_conn(player()), %{"arg" => "edit 练剑"})
    assert output_text(conn) =~ "设置了一份新的计划"
    assert updated_meta(conn).schedule == "练剑"
  end

  test "查看已制订的计划" do
    p = %{player() | meta: %{player().meta | schedule: "打坐 一刻钟"}}
    conn = SchemeCommand.run(build_conn(p), %{"arg" => "show"})
    assert output_text(conn) =~ "打坐 一刻钟"
  end

  test "清除计划" do
    p = %{player() | meta: %{player().meta | schedule: "打坐"}}
    conn = SchemeCommand.run(build_conn(p), %{"arg" => "clear"})
    assert output_text(conn) =~ "Ok."
    assert updated_meta(conn).schedule == nil
  end

  test "空计划被拒绝" do
    p = %{player() | meta: %{player().meta | schedule: nil}}
    conn = SchemeCommand.run(build_conn(p), %{"arg" => "edit"})
    assert output_text(conn) =~ "直接制订你的计划"
  end

  test "超长计划被拒绝" do
    long = String.duplicate("a", 500)
    conn = SchemeCommand.run(build_conn(player()), %{"arg" => long})
    assert output_text(conn) =~ "太长了"
  end

  test "scheme/计划 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("scheme")
    assert parsed.module == Kantele.Character.SchemeCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("计划")
    assert parsed.module == Kantele.Character.SchemeCommand
  end
end

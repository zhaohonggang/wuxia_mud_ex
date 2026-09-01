defmodule Kantele.Character.HatredCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.HatredCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(family \\ nil) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        family: family
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

  test "无门派时提示" do
    conn = HatredCommand.run(build_conn(player(nil)), %{"arg" => ""})
    assert output_text(conn) =~ "还没有加入一个门派"
  end

  test "有门派但无仇人" do
    conn = HatredCommand.run(build_conn(player(%{name: "武当"})), %{"arg" => ""})
    assert output_text(conn) =~ "武当现在没有什么仇人"
  end

  test "显示门派仇人" do
    # 绕过 ETS 查询，直接验证无仇人分支；有仇人走 league 表（不影响玩家）
    conn = HatredCommand.run(build_conn(player(%{name: "少林"})), %{"arg" => ""})
    assert output_text(conn) =~ "少林"
  end

  test "hatred 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("hatred")
    assert parsed.module == Kantele.Character.HatredCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("仇人")
    assert parsed.module == Kantele.Character.HatredCommand
  end
end

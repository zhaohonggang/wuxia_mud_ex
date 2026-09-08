defmodule Kantele.Character.PromoteCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias ExVenture.Characters.Character
  alias ExVenture.Repo
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.PromoteCommand
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
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp arch, do: player(%{attributes: %{"wiz_level" => 2}})

  defp run(character, arg), do: PromoteCommand.run(build_conn(character), %{"arg" => arg})

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)
    :ok
  end

  test "非天神无权限" do
    conn = run(player(), "李四 1")
    assert output_text(conn) =~ "你没有天神的权限"
  end

  test "缺少参数提示用法" do
    conn = run(arch(), nil)
    assert output_text(conn) =~ "指令格式：promote <玩家> <等级>"

    conn = run(arch(), "李四")
    assert output_text(conn) =~ "指令格式：promote <玩家> <等级>"
  end

  test "非数字或越界等级报错" do
    conn = run(arch(), "李四 abc")
    assert output_text(conn) =~ "指令格式"

    conn = run(arch(), "李四 9")
    assert output_text(conn) =~ "没有这种等级"
  end

  test "不能提升到高于自身等级" do
    conn = run(arch(), "李四 3")
    assert output_text(conn) =~ "你没有这种权力"
  end

  test "目标不存在报错" do
    conn = run(arch(), "不存在 1")
    assert output_text(conn) =~ "你只能改变玩家的权限"
  end

  test "提升玩家权限并落库" do
    Repo.insert!(%Character{name: "李四", wiz_level: 0})

    conn = run(arch(), "李四 1")
    assert output_text(conn) =~ "你将 李四 的权限提升为 1 级巫师"

    [updated] = Repo.all(Character)
    assert updated.name == "李四"
    assert updated.wiz_level == 1
  end

  test "路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("promote 李四 1")
    assert parsed.module == PromoteCommand
  end
end

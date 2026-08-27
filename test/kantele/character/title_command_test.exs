defmodule Kantele.Character.TitleCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.TitleCommand
  alias Kantele.Character.Vitals

  defp player(opts \\ %{}) do
    meta =
      %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
      |> Map.put(:title, Map.get(opts, :title, ""))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: meta
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

  test "无参数显示当前头衔（空）" do
    conn = TitleCommand.run(build_conn(player()), %{"rest" => ""})
    assert output_text(conn) =~ "没有任何头衔"
  end

  test "设置头衔" do
    conn = TitleCommand.run(build_conn(player()), %{"rest" => "武林盟主"})
    updated = conn.private.update_character || conn.character
    assert updated.meta.title == "武林盟主"
    assert output_text(conn) =~ "佩戴"
  end

  test "title none 清除" do
    char = %{player() | meta: %{player().meta | title: "武林盟主"}}
    conn = TitleCommand.run(build_conn(player(%{title: "武林盟主"})), %{"rest" => "none"})
    updated = conn.private.update_character || conn.character
    assert updated.meta.title == ""
    assert output_text(conn) =~ "摘下"
  end

  test "超长拒绝" do
    long = String.duplicate("字", 40)
    conn = TitleCommand.run(build_conn(player()), %{"rest" => long})
    assert output_text(conn) =~ "太长了"
  end

  test "title 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("title 武林盟主")
    assert parsed.module == Kantele.Character.TitleCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("头衔 武林盟主")
    assert parsed.module == Kantele.Character.TitleCommand
  end
end

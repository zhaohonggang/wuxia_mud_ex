defmodule Kantele.Character.AliasCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AliasCommand
  alias Kantele.Character.Aliases
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ %{}) do
    meta =
      %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
      |> Map.put(:alias_commands, Map.get(opts, :aliases, %{}))

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

  describe "alias 列表" do
    test "无别名提示" do
      conn = AliasCommand.run(build_conn(player()), %{"rest" => ""})
      assert output_text(conn) =~ "并没有设定任何 alias"
    end

    test "列出已有别名" do
      conn =
        AliasCommand.run(build_conn(player(%{aliases: %{"sc" => "say $1"}})), %{"rest" => ""})

      assert output_text(conn) =~ "sc"
      assert output_text(conn) =~ "say"
    end
  end

  describe "alias 设置与删除" do
    test "设置别名" do
      conn = AliasCommand.run(build_conn(player()), %{"rest" => "jj say"})
      updated = conn.private.update_character || conn.character
      assert updated.meta.alias_commands["jj"] == "say"
      assert output_text(conn) =~ "替代"
    end

    test "不能覆盖 alias 本身" do
      conn = AliasCommand.run(build_conn(player()), %{"rest" => "alias say"})
      assert output_text(conn) =~ "不能将 \"alias\""
    end

    test "不能覆盖系统动词" do
      conn = AliasCommand.run(build_conn(player()), %{"rest" => "look say"})
      assert output_text(conn) =~ "常用命令"
    end

    test "删除已有别名" do
      char = %{player() | meta: %{player().meta | alias_commands: %{"sc" => "say"}}}
      conn = AliasCommand.run(build_conn(player(%{aliases: %{"sc" => "say"}})), %{"rest" => "sc"})
      updated = conn.private.update_character || conn.character
      refute Map.has_key?(updated.meta.alias_commands, "sc")
      assert output_text(conn) =~ "取消了"
    end

    test "删除不存在的别名提示" do
      conn = AliasCommand.run(build_conn(player()), %{"rest" => "xx"})
      assert output_text(conn) =~ "并没有设定"
    end
  end

  describe "Aliases.expand 展开" do
    test "展开带占位符的别名" do
      assert Aliases.expand("sc 大家好", %{"sc" => "say $1"}) == {"say 大家好", true}
    end

    test "多参数占位" do
      assert Aliases.expand("send 张三 你好", %{"send" => "give $2 to $1"}) == {"give 你好 to 张三", true}
    end

    test "无占位模板整串替换" do
      assert Aliases.expand("g", %{"g" => "give 张三 长剑"}) == {"give 张三 长剑", true}
    end

    test "未设定别名原样返回" do
      assert Aliases.expand("hello world", %{}) == {"hello world", false}
    end
  end

  test "alias 路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("alias sc say")
    assert parsed.module == Kantele.Character.AliasCommand

    {:ok, parsed} = Kantele.Character.Commands.parse("别名 sc say")
    assert parsed.module == Kantele.Character.AliasCommand
  end
end

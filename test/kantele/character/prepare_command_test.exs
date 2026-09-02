defmodule Kantele.Character.PrepareCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PrepareCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
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

  describe "prepare 命令" do
    test "prepare 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("prepare finger strike")
      assert parsed.module == PrepareCommand
    end

    test "中文别名 备招 finger strike 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("备招 finger strike")
      assert parsed.module == PrepareCommand
    end

    test "无参数显示当前状态" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => ""})
      text = output_text(conn)
      assert text =~ "目前没有组合"
    end

    test "none 取消全部准备" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => "none"})
      text = output_text(conn)
      assert text =~ "取消全部"
    end

    test "? 显示可用种类" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => "?"})
      text = output_text(conn)
      assert text =~ "指法"
      assert text =~ "手法"
      assert text =~ "拳法"
      assert text =~ "爪法"
      assert text =~ "掌法"
      assert text =~ "拳脚"
    end

    test "无效类型报错" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => "sword"})
      text = output_text(conn)
      assert text =~ "不是有效的拳术种类"
    end

    test "同类型报错" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => "finger finger"})
      text = output_text(conn)
      assert text =~ "不能组合"
    end

    test "单一类型报错" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => "finger"})
      text = output_text(conn)
      assert text =~ "需要指定第二种"
    end

    test "两有效类型报未实装" do
      conn = PrepareCommand.run(build_conn(player()), %{"action" => "finger strike"})
      text = output_text(conn)
      assert text =~ "暂未实装组合逻辑"
    end
  end
end

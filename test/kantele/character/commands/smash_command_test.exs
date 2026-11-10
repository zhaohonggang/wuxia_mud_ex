defmodule Kantele.Character.Commands.SmashCommandTest do
  @moduledoc """
  B2 — smash 命令真化测试：LPC `smash.c` 语法 / 巫师门控 / smash/strike 事件载荷。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.SmashCommand

  defp player(opts) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "大巫"),
      pid: self(),
      room_id: "test:room",
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %Kantele.Character.PlayerMeta{
        vitals: %Kantele.Character.Vitals{},
        stats: %Kantele.Character.Stats{},
        temp: %{}
      }
    }
  end

  defp arch_player(), do: player(id: "arch-1", name: "大巫", attributes: %{"wiz_level" => 2})
  defp wiz_player(), do: player(id: "wiz-1", name: "小巫", attributes: %{"wiz_level" => 1})
  defp mortal_player(), do: player(id: "mortal-1", name: "平民", attributes: %{"wiz_level" => 0})

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "权限门控" do
    test "非巫师被拒绝" do
      conn = SmashCommand.run(build_conn(mortal_player()), %{"rest" => "张三"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "普通巫师不能施展雷劈" do
      conn = SmashCommand.run(build_conn(wiz_player()), %{"rest" => "张三"})
      assert output_text(conn) =~ "只有 arch 巫师"
    end
  end

  describe "语法" do
    test "无参数提示格式" do
      conn = SmashCommand.run(build_conn(arch_player()), %{"rest" => ""})
      assert output_text(conn) =~ "指令格式"
    end
  end

  describe "雷劈事件载荷" do
    test "发出 smash/strike 事件，带目标/施法者/等级/死因" do
      conn = SmashCommand.run(build_conn(arch_player()), %{"rest" => "张三"})

      assert output_text(conn) =~ "闪电"
      refute output_text(conn) =~ "未建模"
      refute output_text(conn) =~ "W3 对象系统"

      event = Enum.find(conn.events, &(&1.topic == "smash/strike"))
      refute is_nil(event)
      assert event.data.target_name == "张三"
      assert event.data.smiter_name == "大巫"
      assert event.data.smiter_level == 2
      assert event.data.die_reason == "被大巫用雷劈死了"
    end

    test "自劈（目标名与自身相同）使用 LPC 专用死因" do
      conn = SmashCommand.run(build_conn(arch_player()), %{"rest" => "大巫"})

      event = Enum.find(conn.events, &(&1.topic == "smash/strike"))
      assert event.data.die_reason == "活得不耐烦，用雷把自己劈死了"
    end
  end
end

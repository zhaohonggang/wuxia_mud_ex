defmodule Kantele.Character.Commands.PurgeCommandTest do
  @moduledoc """
  B2 — purge 命令真化测试：LPC `purge.c` 的 because 语法 / 巫师门控 / 自删拦截。

  `ExVenture.Characters.delete_by_name/1` 在无 Postgres 的测试环境下会 rescue
  成 `{:error, :db_unavailable}`，故「成功删除」用例断言「不崩 + 有明确回执」，
  不依赖真实 DB 删除结果。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.PurgeCommand
  alias Kalevala.Character.Conn.Text

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
      conn = PurgeCommand.run(build_conn(mortal_player()), %{"rest" => "张三 because 灌水"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "普通巫师不能删除人物" do
      conn = PurgeCommand.run(build_conn(wiz_player()), %{"rest" => "张三 because 灌水"})
      assert output_text(conn) =~ "只有 arch 巫师"
    end
  end

  describe "LPC because 语法" do
    test "无参数提示用法" do
      conn = PurgeCommand.run(build_conn(arch_player()), %{"rest" => ""})
      assert output_text(conn) =~ "用法"
    end

    test "缺少 because / 原因提示用法" do
      conn = PurgeCommand.run(build_conn(arch_player()), %{"rest" => "张三"})
      assert output_text(conn) =~ "用法"
    end
  end

  describe "自删拦截（LPC wiz_level(me) <= wiz_level(name)）" do
    test "不能删除自己" do
      conn = PurgeCommand.run(build_conn(arch_player()), %{"rest" => "大巫 because 测试"})
      assert output_text(conn) =~ "没有权限删除这个人物"
    end
  end

  describe "合法 purge：不再返回「未建模」，且明确回执" do
    test "带原因的删除给出明确结果且不崩溃" do
      conn = PurgeCommand.run(build_conn(arch_player()), %{"rest" => "张三 because 灌水"})
      text = output_text(conn)

      # 真化后绝不出现「W3 对象系统未建模」占位回执
      refute text =~ "未建模"
      refute text =~ "W3 对象系统"

      # 无论 DB 是否可用，都应有明确回执（删除成功 / 无此人 / DB 不可用）
      assert text =~ "删除掉了" or text =~ "没有这位使用者" or text =~ "暂时不可用"
    end
  end
end

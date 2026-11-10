defmodule Kantele.Character.Commands.RegisterCommandTest do
  @moduledoc """
  B2 — register 命令真化测试：LPC `register.c` 的 `<id> <email>` 语法 / 巫师门控 /
  明确回执。

  `ExVenture.Users.register_by_username/2` 在无 Postgres 的测试环境下 rescue 成
  `{:error, :db_unavailable}`，故用例断言「不崩 + 有明确回执 + 不再返回未建模」，
  不依赖真实 DB 写入结果。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.RegisterCommand

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
      conn = RegisterCommand.run(build_conn(mortal_player()), %{"rest" => "zhangsan a@b.com"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "普通巫师不能登记" do
      conn = RegisterCommand.run(build_conn(wiz_player()), %{"rest" => "zhangsan a@b.com"})
      assert output_text(conn) =~ "只有 arch 巫师"
    end
  end

  describe "LPC 语法" do
    test "无参数提示格式" do
      conn = RegisterCommand.run(build_conn(arch_player()), %{"rest" => ""})
      assert output_text(conn) =~ "指令格式"
    end

    test "只给 id 提示格式" do
      conn = RegisterCommand.run(build_conn(arch_player()), %{"rest" => "zhangsan"})
      assert output_text(conn) =~ "指令格式"
    end

    test "参数过多提示格式" do
      conn = RegisterCommand.run(build_conn(arch_player()), %{"rest" => "a b c"})
      assert output_text(conn) =~ "指令格式"
    end
  end

  describe "合法 register：不再返回「未建模」，且明确回执" do
    test "带 id + email 给出明确结果且不崩溃" do
      conn = RegisterCommand.run(build_conn(arch_player()), %{"rest" => "zhangsan zhang@example.com"})
      text = output_text(conn)

      refute text =~ "未建模"
      refute text =~ "W3 对象系统"

      assert text =~ "已经成功地被您登记了" or text =~ "登记失败" or text =~ "暂时不可用" or
               text =~ "邮箱格式不正确"
    end
  end
end

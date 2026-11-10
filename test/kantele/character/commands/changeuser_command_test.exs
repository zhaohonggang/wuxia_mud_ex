defmodule Kantele.Character.Commands.ChangeuserCommandTest do
  @moduledoc """
  B2 — changeuser 命令真化测试：LPC `changename.c` 的 [-f] 语法 / 中文名校验 /
  在线目标检查 / 巫师门控。

  `ExVenture.Characters.rename_by_name/2` 在无 Postgres 的测试环境下 rescue 成
  `{:error, :db_unavailable}`；且 Presence 未启动时在线目标为空，故「成功改名」
  路径不做 DB 断言，仅验证语法/校验/门控与「不再返回未建模」。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.ChangeuserCommand
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
      conn = ChangeuserCommand.run(build_conn(mortal_player()), %{"rest" => "张三 李四"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "普通巫师不能改名" do
      conn = ChangeuserCommand.run(build_conn(wiz_player()), %{"rest" => "张三 李四"})
      assert output_text(conn) =~ "只有 arch 巫师"
    end
  end

  describe "LPC 语法" do
    test "无参数提示格式" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => ""})
      assert output_text(conn) =~ "格式"
    end

    test "参数不足提示格式" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "张三"})
      assert output_text(conn) =~ "格式"
    end

    test "参数过多提示格式" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "张三 李四 王五"})
      assert output_text(conn) =~ "格式"
    end

    test "-f 标志被接受（不破坏双参数解析）" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "-f 张三 李四"})
      text = output_text(conn)
      refute text =~ "格式"
      refute text =~ "未建模"
    end
  end

  describe "check_legal_name（LPC is_chinese + maxlen 8）" do
    test "非中文名被拒绝" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "张三 Alibaba"})
      assert output_text(conn) =~ "请你用中文取名字"
    end

    test "中英混排被拒绝" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "张三 李a四"})
      assert output_text(conn) =~ "请你用中文取名字"
    end

    test "超过 8 个中文字被拒绝" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "张三 一二三四五六七八九"})
      assert output_text(conn) =~ "不能超过 8 个字"
    end
  end

  describe "在线目标检查" do
    test "合法中文名但目标不在线时提示（不崩、不返回未建模）" do
      conn = ChangeuserCommand.run(build_conn(arch_player()), %{"rest" => "张三 李四"})
      text = output_text(conn)

      refute text =~ "未建模"
      refute text =~ "W3 对象系统"
      assert text =~ "这个玩家不在线上" or text =~ "没有这位使用者" or text =~ "暂时不可用" or
               text =~ "成功的修改了"
    end
  end
end

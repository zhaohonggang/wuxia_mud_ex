defmodule Kantele.Character.Commands.GrantCommandTest do
  @moduledoc """
  B2 — grant 命令真化测试：巫师门控 + 授权 / 撤销 + arch-only 限制。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Admin.Security
  alias Kantele.Character.GrantCommand
  alias Kalevala.Character.Conn.Text

  setup do
    Security.ensure!()
    Security.clear("张三")
    :ok
  end

  defp vitals do
    %Kantele.Character.Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }
  end

  defp stats do
    %Kantele.Character.Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      combat_exp: 0
    }
  end

  defp player(opts) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %Kantele.Character.PlayerMeta{
        vitals: vitals(),
        stats: stats(),
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
      conn = GrantCommand.run(build_conn(mortal_player()), %{"rest" => "张三 clone"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "普通巫师（wiz_level 1）不能授权" do
      conn = GrantCommand.run(build_conn(wiz_player()), %{"rest" => "张三 clone"})
      assert output_text(conn) =~ "只有 arch 巫师（及以上）可以授权"
    end

    test "arch 巫师可授权" do
      conn = GrantCommand.run(build_conn(arch_player()), %{"rest" => "张三 clone"})
      assert output_text(conn) =~ "已授予 张三 使用命令：clone"
      assert Security.granted?("张三", "clone")
    end
  end

  describe "授权 / 撤销" do
    test "授予多个命令" do
      conn = GrantCommand.run(build_conn(arch_player()), %{"rest" => "张三 clone to"})
      text = output_text(conn)
      assert text =~ "已授予 张三 使用命令：clone"
      assert text =~ "已授予 张三 使用命令：to"
      assert Enum.sort(Security.list_for("张三")) == ["clone", "to"]
    end

    test "经过 -d 撤销" do
      _conn = GrantCommand.run(build_conn(arch_player()), %{"rest" => "张三 clone to"})
      conn2 = GrantCommand.run(build_conn(arch_player()), %{"rest" => "-d 张三 clone"})

      assert output_text(conn2) =~ "已撤销 张三 的命令授权：clone"
      refute Security.granted?("张三", "clone")
      assert Security.granted?("张三", "to")
    end
  end

  describe "用法提示" do
    test "无参数时提示用法" do
      conn = GrantCommand.run(build_conn(arch_player()), %{"rest" => ""})
      assert output_text(conn) =~ "用法"
    end

    test "只有目标无命令时提示用法" do
      conn = GrantCommand.run(build_conn(arch_player()), %{"rest" => "张三"})
      assert output_text(conn) =~ "用法"
    end

    test "撤销但缺命令时提示用法" do
      conn = GrantCommand.run(build_conn(arch_player()), %{"rest" => "-d 张三"})
      assert output_text(conn) =~ "用法"
    end
  end
end

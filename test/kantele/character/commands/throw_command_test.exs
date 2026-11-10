defmodule Kantele.Character.Commands.ThrowCommandTest do
  @moduledoc """
  B2 — throw 命令真化测试：LPC `throw.c` 的 because 理由 / 时长 / 自禁闭拦截。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Admin.Prison
  alias Kantele.Character.ThrowCommand
  alias Kalevala.Character.Conn.Text

  setup do
    Prison.ensure!()
    Prison.release("张三")
    :ok
  end

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
      conn = ThrowCommand.run(build_conn(mortal_player()), %{"rest" => "张三 because flood"})
      assert output_text(conn) =~ "没有巫师的权限"
    end

    test "普通巫师不能禁闭" do
      conn = ThrowCommand.run(build_conn(wiz_player()), %{"rest" => "张三 because flood"})
      assert output_text(conn) =~ "只有 arch 巫师"
    end
  end

  describe "LPC because 语法" do
    test "缺少 because / 理由时拒绝" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三"})
      assert output_text(conn) =~ "送人进监狱你必须有一个理由"
    end

    test "理由不在白名单时拒绝" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三 because whatever"})
      assert output_text(conn) =~ "你这个理由也太不充分了"
      refute Prison.in_prison?("张三")
    end

    test "合法理由 + 缺省时长判处 20 分钟" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三 because rude"})

      assert output_text(conn) =~ "禁闭 20 分钟"
      assert Prison.in_prison?("张三")
      assert Prison.detail("张三").reason == "rude"
    end

    test "带时长后缀 2h 判处 120 分钟" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三 2h because flood"})

      assert output_text(conn) =~ "禁闭 120 分钟"
      assert Prison.detail("张三").minutes == 120
    end

    test "非法时长拒绝" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三 2x because flood"})
      assert output_text(conn) =~ "你要禁闭别人多久"
      refute Prison.in_prison?("张三")
    end

    test "零时长拒绝" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三 0 because flood"})
      assert output_text(conn) =~ "你要禁闭别人多久"
    end
  end

  describe "自禁闭拦截（LPC ob == me）" do
    test "不能把自己送进地狱" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "大巫 because flood"})
      assert output_text(conn) =~ "疯了"
      refute Prison.in_prison?("大巫")
    end
  end

  describe "禁闭态接入 heal_up 的 in_prison?" do
    test "判处后 feature_damage 的监狱判定生效" do
      conn = ThrowCommand.run(build_conn(arch_player()), %{"rest" => "张三 1d because main"})
      assert output_text(conn) =~ "送进了地狱"
      assert Prison.in_prison?("张三") == true
    end
  end
end

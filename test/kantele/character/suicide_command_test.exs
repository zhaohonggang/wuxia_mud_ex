defmodule Kantele.Character.SuicideCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.SuicideCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = %{Combat.new() | busy: Keyword.get(opts, :busy, 0)}

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        password: Keyword.get(opts, :password)
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

  describe "suicide 命令" do
    test "无参数时显示确认提示" do
      conn = SuicideCommand.run(build_conn(player()), %{"rest" => ""})
      text = output_text(conn)
      assert text =~ "自杀方式"
      assert text =~ "资料将永远删除"
      assert text =~ "suicide -f"
      refute conn.private.halt?
    end

    test "空 rest 时显示确认提示" do
      conn = SuicideCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "自杀方式"
      refute conn.private.halt?
    end

    test "-f 不带密码时索要密码" do
      conn = SuicideCommand.run(build_conn(player(name: "张三")), %{"rest" => "-f"})
      text = output_text(conn)
      assert text =~ "管理密码"
      refute conn.private.halt?
      refute conn.assigns[:prompt] == false
    end

    test "-f 密码错误时拒绝" do
      p = player(name: "张三", password: "secret123")
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f wrong"})
      assert output_text(conn) =~ "密码错误"
      refute conn.private.halt?
    end

    test "忙碌时拒绝自杀" do
      p = player(name: "张三", password: "secret123", busy: 3)
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f secret123"})
      assert output_text(conn) =~ "上一个动作还没完成"
      refute conn.private.halt?
    end

    test "-f 正确密码时删除角色并断开" do
      p = player(name: "张三", password: "secret123")
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f secret123"})
      text = output_text(conn)
      assert text =~ "永别了"
      assert text =~ "张三"
      assert conn.private.halt? == true
      assert conn.assigns[:prompt] == false
    end

    test "combat_exp>=1000 时仍执行删除（rumor 广播不阻塞）" do
      p = player(name: "张三", password: "secret123", combat_exp: 2000)
      conn = SuicideCommand.run(build_conn(p), %{"rest" => "-f secret123"})
      assert conn.private.halt? == true
      assert conn.assigns[:prompt] == false
    end
  end
end

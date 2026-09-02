defmodule Kantele.Character.WimpyCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.WimpyCommand
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

    combat = Kantele.Character.Combat.new()
    wimpy = Keyword.get(opts, :wimpy, 0)

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        wimpy: wimpy
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

  describe "wimpy 命令" do
    test "无参数时显示当前设置" do
      p = player(wimpy: 30)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => ""})
      assert output_text(conn) =~ "30%"
    end

    test "无参数时显示未设定" do
      p = player(wimpy: 0)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => ""})
      assert output_text(conn) =~ "没有设定自动逃跑"
    end

    test "设置有效的wimpy值" do
      p = player(wimpy: 0)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => "50"})
      assert output_text(conn) =~ "气低于 50%"
      updated = conn.private.update_character || conn.character
      assert updated.meta.wimpy == 50
    end

    test "设置为0时取消wimpy" do
      p = player(wimpy: 30)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => "0"})
      assert output_text(conn) =~ "取消"
      updated = conn.private.update_character || conn.character
      assert updated.meta.wimpy == 0
    end

    test "超过80拒绝" do
      p = player(wimpy: 0)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => "90"})
      assert output_text(conn) =~ "0-80"
    end

    test "负数拒绝" do
      p = player(wimpy: 0)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => "-10"})
      assert output_text(conn) =~ "0-80"
    end

    test "非数字输入拒绝" do
      p = player(wimpy: 0)
      conn = WimpyCommand.run(build_conn(p), %{"arg" => "abc"})
      assert output_text(conn) =~ "0-80"
    end
  end
end

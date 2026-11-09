defmodule Kantele.Character.PkdCommandTest do
  # 与 SignTest 共用全局 PK_D ETS 表，串行执行避免互相串扰。
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.PkdCommand
  alias Kantele.Character.Pkd
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
      combat_exp: Keyword.get(opts, :combat_exp, 15000),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "pk:entry",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  defp reset_pkd() do
    Pkd.ensure!()
    :ets.delete(:kantele_pkd, :kantele_pkd)
    :ets.insert(:kantele_pkd, {:kantele_pkd, %{state: :none, competitors: %{}}})
  end

  describe "pkd 命令" do
    test "无参数时显示赛事状态（无赛事）" do
      reset_pkd()
      p = player()
      conn = PkdCommand.run(build_conn(p), %{})

      assert output_text(conn) =~ "屠人场赛事状态"
      assert output_text(conn) =~ "当前无屠人赛事"
    end

    test "无参数时报名期显示可 join 提示" do
      reset_pkd()
      Pkd.set_state(:ready)
      p = player()
      conn = PkdCommand.run(build_conn(p), %{})

      assert output_text(conn) =~ "报名期"
      assert output_text(conn) =~ "pkd join"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("pkd")
      assert parsed.module == PkdCommand
    end

    test "join 成功（state 为 :ready）" do
      reset_pkd()
      Pkd.set_state(:ready)
      p = player()
      conn = PkdCommand.run(build_conn(p), %{"rest" => "join"})

      assert output_text(conn) =~ "已成功报名屠人大赛"
      competitors = Pkd.query_all_competitor()
      assert length(competitors) == 1
      assert hd(competitors).name == "张三"
    end

    test "join 被拒绝（state 不是 :ready）" do
      reset_pkd()
      Pkd.set_state(:none)
      p = player()
      conn = PkdCommand.run(build_conn(p), %{"rest" => "join"})

      assert output_text(conn) =~ "现在没要举行比赛啊？你跑来干什么？"
    end

    test "join 重复报名被拒绝" do
      reset_pkd()
      Pkd.set_state(:ready)
      p = player()
      conn1 = PkdCommand.run(build_conn(p), %{"rest" => "join"})
      assert output_text(conn1) =~ "已成功报名"

      conn2 = PkdCommand.run(build_conn(p), %{"rest" => "join"})
      assert output_text(conn2) =~ "已经报名过了"
    end

    test "quit 成功" do
      reset_pkd()
      Pkd.set_state(:ready)
      p = player()
      PkdCommand.run(build_conn(p), %{"rest" => "join"})
      assert length(Pkd.query_all_competitor()) == 1

      conn = PkdCommand.run(build_conn(p), %{"rest" => "quit"})
      assert output_text(conn) =~ "已退出屠人大赛报名"
      assert length(Pkd.query_all_competitor()) == 0
    end

    test "无效子命令提示格式" do
      reset_pkd()
      p = player()
      conn = PkdCommand.run(build_conn(p), %{"rest" => "invalid_subcmd"})

      assert output_text(conn) =~ "指令格式"
    end
  end

  describe "Pkd daemon" do
    test "is_ready/is_pking 随 state 切换" do
      reset_pkd()
      refute Pkd.is_ready()
      refute Pkd.is_pking()

      Pkd.set_state(:ready)
      assert Pkd.is_ready()
      refute Pkd.is_pking()

      Pkd.set_state(:pking)
      refute Pkd.is_ready()
      assert Pkd.is_pking()
    end

    test "reject_join 返回 nil 在 :ready 态且未报名" do
      reset_pkd()
      Pkd.set_state(:ready)
      p = player()
      assert Pkd.reject_join(p) == nil
    end

    test "reject_join 返回文案在非 :ready 态" do
      reset_pkd()
      Pkd.set_state(:none)
      p = player()
      assert Pkd.reject_join(p) =~ "现在没要举行比赛"
    end
  end
end

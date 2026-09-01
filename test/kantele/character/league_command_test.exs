defmodule Kantele.Character.LeagueCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.LeagueCommand
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

    league = Keyword.get(opts, :league, nil)

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        league: league
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

  describe "league 命令" do
    test "无帮派时 league 查看信息提示" do
      conn = LeagueCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "你现在还没有和别人结义成盟呢"
    end

    test "league ? 帮助信息" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "?"})
      text = output_text(conn)
      assert text =~ "指令格式"
      assert text =~ "info"
      assert text =~ "hatred"
      assert text =~ "top"
    end

    test "league set 无参数显示当前设置" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 0, set: %{no_kill: 0, weiwang: 50, follow: 1}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "set"})
      text = output_text(conn)
      assert text =~ "no_kill"
      assert text =~ "weiwang"
    end

    test "league set 修改设置" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "set no_kill 1"})
      assert output_text(conn) =~ "OK"
    end

    test "league set 无效参数" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "set invalid_param 1"})
      text = output_text(conn)
      assert text =~ "指令格式"
    end

    test "league top 排行（无帮派）" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "top"})
      text = output_text(conn)
      assert text =~ "排行"
    end

    test "league hatred 无帮派提示" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "hatred"})
      assert output_text(conn) =~ "你现在还没有和别人结义成盟呢"
    end

    test "league add 无帮派拒绝" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "add 某人"})
      assert output_text(conn) =~ "你现在还没有和任何人结义成盟呢"
    end

    test "league add 非领袖无权限" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-2", leader_name: "李四", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "add 某人"})
      assert output_text(conn) =~ "没有足够权限"
    end

    test "league kick 无帮派拒绝" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "kick 某人"})
      assert output_text(conn) =~ "你现在还没有和任何人结义成盟呢"
    end

    test "league kick 非领袖无权限" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-2", leader_name: "李四", grant: 1, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "kick player-3"})
      assert output_text(conn) =~ "没有足够权限开除成员"
    end

    test "league kick 自己踢自己" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "kick player-1"})
      assert output_text(conn) =~ "自己踢自己"
    end

    test "league kick 踢领袖" do
      p = player(id: "player-3", league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 3, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "kick player-1"})
      assert output_text(conn) =~ "连领袖都敢踢"
    end

    test "league dismiss 无帮派拒绝" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "dismiss"})
      assert output_text(conn) =~ "你现在还没有和任何人结义成盟呢"
    end

    test "league dismiss 非领袖拒绝" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-2", leader_name: "李四", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "dismiss"})
      assert output_text(conn) =~ "只有同盟领袖才能解散同盟"
    end

    test "league out 无帮派拒绝" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "out"})
      assert output_text(conn) =~ "你现在还没有和任何人结义成盟呢"
    end

    test "league out 第一次确认" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "out"})
      assert output_text(conn) =~ "背弃"
      assert output_text(conn) =~ "再输入一次"
    end

    test "league grant 格式错误" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-1", leader_name: "张三", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "grant"})
      assert output_text(conn) =~ "指令格式"
    end

    test "league grant 非领袖拒绝" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-2", leader_name: "李四", grant: 0, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "grant player-3 1"})
      assert output_text(conn) =~ "只有同盟领袖才能使用该指令"
    end

    test "league join 无邀请" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "join"})
      assert output_text(conn) =~ "现在没有同盟邀请你加入"
    end

    test "league kill 无帮派" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "kill 某人"})
      assert output_text(conn) =~ "你现在还没有和任何人结义成盟呢"
    end

    test "league kill 非领袖无权限" do
      p = player(league: %{league_name: "江湖帮", leader_id: "player-2", leader_name: "李四", grant: 1, set: %{}})
      conn = LeagueCommand.run(build_conn(p), %{"rest" => "kill 某人"})
      assert output_text(conn) =~ "没有足够权限号召同盟成员"
    end

    test "league info 无帮派" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "info"})
      assert output_text(conn) =~ "你现在还没有和别人结义成盟呢"
    end

    test "league member 无帮派" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "member"})
      assert output_text(conn) =~ "你现在还没有加入任何一个同盟呢"
    end

    test "league 无效子命令" do
      conn = LeagueCommand.run(build_conn(player()), %{"rest" => "invalid_cmd"})
      assert output_text(conn) =~ "无效的参数"
    end
  end
end

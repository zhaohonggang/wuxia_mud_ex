defmodule Kantele.Character.VoteCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.VoteCommand
  alias Kantele.Character.Vote
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

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
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

  defp reset_vote() do
    Vote.ensure!()
    :ets.delete(:kantele_vote, :kantele_vote)
    :ets.insert(:kantele_vote, {:kantele_vote, %{votes: %{}}})
  end

  describe "vote 命令" do
    test "无参数时显示动议列表（无动议）" do
      reset_vote()
      p = player()
      conn = VoteCommand.run(build_conn(p), %{})

      assert output_text(conn) =~ "投票动议列表"
      assert output_text(conn) =~ "暂无进行中的投票动议"
    end

    test "有进行中的动议时列出" do
      reset_vote()
      p = player(id: "initiator", name: "张三")
      VoteCommand.run(build_conn(p), %{"rest" => "chblk 李四"})

      conn = VoteCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "投票动议列表"
      assert output_text(conn) =~ "李四"
      assert output_text(conn) =~ "张三"
    end

    test "路由解析（裸命令）" do
      {:ok, parsed} = Kantele.Character.Commands.parse("vote")
      assert parsed.module == VoteCommand
    end

    test "路由解析（带参）" do
      {:ok, parsed} = Kantele.Character.Commands.parse("vote chblk 李四")
      assert parsed.module == VoteCommand
      assert parsed.params["rest"] == "chblk 李四"
    end

    test "发起 chblk 动议成功" do
      reset_vote()
      p = player(id: "player-1", name: "张三")
      conn = VoteCommand.run(build_conn(p), %{"rest" => "chblk 李四"})

      assert output_text(conn) =~ "发起了"
      assert output_text(conn) =~ "关闭频道"
      assert output_text(conn) =~ "等待其他玩家附议"

      votes = Vote.query_all_votes()
      assert length(votes) == 1
      assert hd(votes).act == "chblk"
      assert hd(votes).victim == "李四"
      assert hd(votes).initiator_name == "张三"
    end

    test "发起 unchblk 动议成功" do
      reset_vote()
      p = player(id: "player-1", name: "张三")
      conn = VoteCommand.run(build_conn(p), %{"rest" => "unchblk 李四"})

      assert output_text(conn) =~ "打开频道"

      votes = Vote.query_all_votes()
      assert length(votes) == 1
      assert hd(votes).act == "unchblk"
    end

    test "重复发起同一动议则转为附议" do
      reset_vote()
      p1 = player(id: "player-1", name: "张三")
      p2 = player(id: "player-2", name: "李四")

      conn1 = VoteCommand.run(build_conn(p1), %{"rest" => "chblk 王五"})
      assert output_text(conn1) =~ "发起了"

      conn2 = VoteCommand.run(build_conn(p2), %{"rest" => "chblk 王五"})
      assert output_text(conn2) =~ "附议"

      votes = Vote.query_all_votes()
      assert length(votes) == 1
      assert map_size(hd(votes).voters) == 2
    end

    test "无效动议类型提示帮助" do
      reset_vote()
      p = player()
      conn = VoteCommand.run(build_conn(p), %{"rest" => "invalid 李四"})

      assert output_text(conn) =~ "用法"
    end

    test "缺少受众参数显示帮助" do
      reset_vote()
      p = player()
      conn = VoteCommand.run(build_conn(p), %{"rest" => "chblk"})

      assert output_text(conn) =~ "用法"
    end

    test "自身发起的动议不能自附议" do
      reset_vote()
      p = player(id: "player-1", name: "张三")
      VoteCommand.run(build_conn(p), %{"rest" => "chblk 李四"})

      conn = VoteCommand.run(build_conn(p), %{"rest" => "chblk 李四"})
      assert output_text(conn) =~ "发起人"
    end
  end

  describe "Vote daemon" do
    test "is_voting? 随动议状态切换" do
      reset_vote()
      refute Vote.is_voting?

      Vote.create_vote(player(id: "p1", name: "张三"), "chblk", "李四")
      assert Vote.is_voting?

      vote_id = hd(Vote.query_all_votes()).id
      Vote.tally(vote_id)
      refute Vote.is_voting?
    end

    test "query_all_votes 仅返回 active 动议" do
      reset_vote()
      Vote.create_vote(player(id: "p1", name: "张三"), "chblk", "李四")
      Vote.create_vote(player(id: "p2", name: "王五"), "unchblk", "赵六")

      assert length(Vote.query_all_votes()) == 2

      vote_id = hd(Vote.query_all_votes()).id
      Vote.tally(vote_id)

      assert length(Vote.query_all_votes()) == 1
    end

    test "cast_vote 重复投票被拒绝" do
      reset_vote()
      p1 = player(id: "p1", name: "张三")
      p2 = player(id: "p2", name: "李四")
      {:ok, vid} = Vote.create_vote(p1, "chblk", "李四")
      Vote.cast_vote(p2, vid)
      assert Vote.cast_vote(p2, vid) == {:error, :already_voted}
    end

    test "cast_vote 非 active 动议被拒绝" do
      reset_vote()
      p = player(id: "p1", name: "张三")
      {:ok, vid} = Vote.create_vote(p, "chblk", "李四")
      Vote.tally(vid)
      assert Vote.cast_vote(p, vid) == {:error, :finished}
    end

    test "tally 不足阈值判定 failed" do
      reset_vote()
      p = player(id: "p1", name: "张三")
      {:ok, vid} = Vote.create_vote(p, "chblk", "李四")
      {:ok, result, count} = Vote.tally(vid)
      assert result == :failed
      assert count == 1
    end

    test "tally 达到阈值判定 passed" do
      reset_vote()
      p1 = player(id: "p1", name: "张三")
      p2 = player(id: "p2", name: "李四")
      p3 = player(id: "p3", name: "王五")

      {:ok, vid} = Vote.create_vote(p1, "chblk", "赵六")
      Vote.cast_vote(p2, vid)
      Vote.cast_vote(p3, vid)

      {:ok, result, count} = Vote.tally(vid)
      assert result == :passed
      assert count == 3
    end

    test "cancel_vote 移除动议" do
      reset_vote()
      p = player(id: "p1", name: "张三")
      {:ok, vid} = Vote.create_vote(p, "chblk", "李四")
      assert Vote.is_voting?

      Vote.cancel_vote(vid)
      refute Vote.is_voting?
    end
  end
end

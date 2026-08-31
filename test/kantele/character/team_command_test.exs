defmodule Kantele.Character.TeamCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Team
  alias Kantele.Character.TeamCommand
  alias Kantele.Character.TeamEvent
  alias Kantele.Character.Vitals

  defp player(opts \\ %{}) do
    opts = Map.new(opts)

    meta =
      %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
      |> Map.put(:team, Map.get(opts, :team))
      |> Map.put(:team_pending, Map.get(opts, :team_pending))

    %Kalevala.Character{
      id: Map.get(opts, :id, "player-1"),
      name: Map.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      meta: meta
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

  defp team_with(members) do
    %{id: "team_x", leader_pid: self(), members: members, formation: nil}
  end

  defp member(id, pid, name), do: %{id: id, pid: pid, name: name}

  describe "路由与子命令分发" do
    test "team 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("team list")
      assert parsed.module == Kantele.Character.TeamCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("组队 with 李四")
      assert parsed.module == Kantele.Character.TeamCommand
    end

    test "无队伍时 list 提示" do
      conn = TeamCommand.run(build_conn(player()), %{"rest" => ""})
      assert output_text(conn) =~ "没有参加任何队伍"
    end

    test "with 邀请发 team/invite 事件" do
      conn = TeamCommand.run(build_conn(player()), %{"rest" => "with 李四"})
      assert [%Event{topic: "team/invite", data: %{name: "李四"}}] = conn.events
      assert conn.assigns[:prompt] == false
    end
  end

  describe "list 名单" do
    test "列出队伍成员与队长" do
      team = team_with([member("player-1", self(), "张三"), member("player-2", self(), "李四")])
      conn = TeamCommand.run(build_conn(player(team: team)), %{"rest" => "list"})
      text = output_text(conn)
      assert text =~ "张三"
      assert text =~ "李四"
      assert text =~ "队长"
    end
  end

  describe "talk 队伍会话" do
    test "无队伍提示" do
      conn = TeamCommand.run(build_conn(player()), %{"rest" => "talk 大家好"})
      assert output_text(conn) =~ "没有和别人组成队伍"
    end

    test "在队伍中发送 team/talk 给自己" do
      team = team_with([member("player-1", self(), "张三"), member("player-2", self(), "李四")])
      conn = TeamCommand.run(build_conn(player(team: team)), %{"rest" => "talk 大家好"})

      assert_receive %Event{topic: "team/talk", data: %{from_name: "张三", text: "大家好"}}
      assert conn.assigns[:prompt] == false
    end

    test "TeamEvent.talk 展示会话" do
      conn =
        TeamEvent.talk(build_conn(player()), %Event{
          topic: "team/talk",
          data: %{from_name: "李四", text: "你好"}
        })

      assert output_text(conn) =~ "【队伍】李四：你好"
    end
  end

  describe "accept 接受邀请" do
    test "无待处理邀请提示" do
      conn = TeamCommand.run(build_conn(player()), %{"rest" => "accept"})
      assert output_text(conn) =~ "并没有收到任何队伍邀请"
    end

    test "有邀请时通知队长 team/accept" do
      leader = member("player-9", self(), "王五")
      conn = TeamCommand.run(build_conn(player(team_pending: leader)), %{"rest" => "accept"})

      assert_receive %Event{topic: "team/accept", data: %{accepter: accepter}}
      assert accepter.name == "张三"
      assert conn.assigns[:prompt] == false
    end

    test "队长侧 accept 创建新队伍" do
      accepter = member("player-2", self(), "李四")

      conn =
        TeamEvent.accept(build_conn(player()), %Event{
          topic: "team/accept",
          data: %{accepter: accepter}
        })

      updated = conn.private.update_character || conn.character
      team = updated.meta.team
      assert team.leader_pid == self()
      assert length(team.members) == 1
      assert hd(team.members).name == "张三"
      assert updated.meta.team_pending == nil
      assert output_text(conn) =~ "加入了你的队伍"
    end
  end

  describe "set_team 写入队伍" do
    test "被邀者接受后写入 team 并清 pending" do
      team = team_with([member("player-1", self(), "张三"), member("player-2", self(), "李四")])

      conn =
        TeamEvent.set_team(
          build_conn(player(team_pending: member("player-9", self(), "王五"))),
          %Event{
            topic: "team/set",
            data: %{team: team}
          }
        )

      updated = conn.private.update_character || conn.character
      assert updated.meta.team.id == "team_x"
      assert updated.meta.team_pending == nil
      assert output_text(conn) =~ "加入了队伍"
    end
  end

  describe "dismiss 解散/离开" do
    test "队长解散队伍并通知成员" do
      test_pid = self()

      other_pid =
        spawn(fn ->
          receive do
            %Event{topic: "team/disband", data: %{leader_name: "张三"}} ->
              send(test_pid, :disbanded)
          end
        end)

      team = team_with([member("player-1", self(), "张三"), member("player-2", other_pid, "李四")])

      conn = TeamCommand.run(build_conn(player(team: team)), %{"rest" => "dismiss"})

      assert_receive :disbanded
      updated = conn.private.update_character || conn.character
      assert updated.meta.team == nil
      assert output_text(conn) =~ "解散"
      Process.exit(other_pid, :kill)
    end

    test "非队长离开" do
      test_pid = self()

      leader_pid =
        spawn(fn ->
          receive do
            %Event{topic: "team/member-left", data: %{member_name: "张三"}} ->
              send(test_pid, :member_left)
          end
        end)

      team = %{
        id: "team_x",
        leader_pid: leader_pid,
        members: [member("player-1", self(), "张三"), member("player-2", leader_pid, "王五")],
        formation: nil
      }

      conn = TeamCommand.run(build_conn(player(team: team)), %{"rest" => "dismiss"})

      assert_receive :member_left
      updated = conn.private.update_character || conn.character
      assert updated.meta.team == nil
      Process.exit(leader_pid, :kill)
    end
  end

  describe "kick 踢出" do
    test "只有队长能踢" do
      leader_pid = spawn(fn -> Process.sleep(:infinity) end)

      team = %{
        id: "team_x",
        leader_pid: leader_pid,
        members: [member("player-1", self(), "张三"), member("player-2", leader_pid, "王五")],
        formation: nil
      }

      conn = TeamCommand.run(build_conn(player(team: team)), %{"rest" => "kick 李四"})
      assert output_text(conn) =~ "只有队伍领袖可以踢人"
      Process.exit(leader_pid, :kill)
    end
  end

  describe "xp_share 经验分享" do
    test "增加 combat_exp 与 potential" do
      conn =
        TeamEvent.xp_share(build_conn(player()), %Event{
          topic: "team/xp-share",
          data: %{exp: 100, potential: 50}
        })

      updated = conn.private.update_character || conn.character
      assert updated.meta.stats.combat_exp == 1100
      assert updated.meta.stats.potential == 150
      assert output_text(conn) =~ "分享了队友"
    end
  end

  test "Team.new 结构" do
    team = Team.new(member("player-1", self(), "张三"))
    assert team.leader_pid == self()
    assert team.members == [%{id: "player-1", pid: self(), name: "张三"}]
    assert team.formation == nil
  end
end

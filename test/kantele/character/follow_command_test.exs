defmodule Kantele.Character.FollowCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.FollowCommand
  alias Kantele.Character.FollowEvent
  alias Kantele.Character.MoveEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(id \\ "player-1", name \\ "张三", opts \\ []) do
    leader = Keyword.get(opts, :leader)
    followers = Keyword.get(opts, :followers, [])

    meta = %PlayerMeta{
      vitals: Vitals.new(),
      stats: Stats.new(),
      combat: Kantele.Character.Combat.new()
    }

    meta =
      case leader do
        nil -> meta
        leader -> %{meta | leader: leader}
      end

    meta = %{meta | followers: followers}

    %Kalevala.Character{
      id: id,
      name: name,
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

  describe "路由解析" do
    test "follow 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("follow 张三")
      assert parsed.function == :run
      assert parsed.params["rest"] == "张三"
    end

    test "中文别名 跟随" do
      {:ok, parsed} = Kantele.Character.Commands.parse("跟随 张三")
      assert parsed.function == :run
    end

    test "follow none" do
      {:ok, parsed} = Kantele.Character.Commands.parse("follow none")
      assert parsed.params["rest"] == "none"
    end
  end

  describe "FollowCommand" do
    test "follow none 且已跟随：清 leader 并通知对方" do
      leader = %{id: "player-2", pid: self(), name: "李四"}
      conn = FollowCommand.run(build_conn(player("player-1", "张三", leader: leader)), %{"rest" => "none"})

      updated = conn.private.update_character || conn.character
      assert updated.meta.leader == nil
      assert output_text(conn) =~ "Ok"

      assert_receive %Event{topic: "follow/unregister", data: %{follower_id: "player-1"}}
    end

    test "follow none 未跟随" do
      conn = FollowCommand.run(build_conn(player()), %{"rest" => "none"})

      assert output_text(conn) =~ "没有跟随"
    end

    test "follow 某人发 room/follow" do
      conn = FollowCommand.run(build_conn(player()), %{"rest" => "李四"})

      assert [%Event{topic: "room/follow", data: %{name: "李四"}}] = conn.events
    end
  end

  describe "FollowEvent" do
    test "set-leader 记录 leader" do
      leader = %{id: "player-2", pid: self(), name: "李四"}

      conn =
        FollowEvent.set_leader(build_conn(player()), %Event{
          topic: "follow/set-leader",
          data: %{leader: leader}
        })

      updated = conn.private.update_character || conn.character
      assert updated.meta.leader.id == "player-2"
      assert output_text(conn) =~ "开始跟随李四"
    end

    test "register 登记跟随者" do
      follower = %{id: "player-1", pid: self(), name: "张三"}

      conn =
        FollowEvent.register(build_conn(player("player-2", "李四")), %Event{
          topic: "follow/register",
          data: %{follower: follower}
        })

      updated = conn.private.update_character || conn.character
      assert [%{id: "player-1"}] = updated.meta.followers
      assert output_text(conn) =~ "张三决定开始跟随你"
    end

    test "unregister 移除跟随者" do
      followers = [%{id: "player-1", pid: self(), name: "张三"}, %{id: "player-3", pid: self(), name: "王五"}]

      conn =
        FollowEvent.unregister(build_conn(player("player-2", "李四", followers: followers)), %Event{
          topic: "follow/unregister",
          data: %{follower_id: "player-1"}
        })

      updated = conn.private.update_character || conn.character
      assert [%{id: "player-3"}] = updated.meta.followers
    end

    test "move 触发跟随移动" do
      conn =
        FollowEvent.move(build_conn(player()), %Event{
          topic: "follow/move",
          data: %{exit_name: "north"}
        })

      assert [%Event{} = event] = conn.events
      assert event.topic == Kalevala.Event.Movement.Request
    end
  end

  describe "MoveEvent.commit 通知跟随者" do
    test "leader 移动通知存活跟随者沿同出口移动" do
      followers = [%{id: "f-1", pid: self(), name: "跟随者"}]
      leader = player("player-1", "张三", followers: followers)

      event = %Event{
        topic: Kalevala.Event.Movement.Commit,
        data: %Kalevala.Event.Movement.Commit{
          character: nil,
          to: "test:room2",
          from: "test:room",
          exit_name: "north"
        }
      }

      MoveEvent.commit(build_conn(leader), event)

      assert_receive %Event{topic: "follow/move", data: %{exit_name: "north"}}
    end
  end
end

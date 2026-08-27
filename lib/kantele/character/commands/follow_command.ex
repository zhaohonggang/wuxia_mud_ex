defmodule Kantele.Character.FollowCommand do
  @moduledoc """
  跟随命令：`follow <某人>` / `follow none`（cmds/std/follow.c）

  `follow none` 清空自己的 leader 并通知对方解除登记；`follow <名字>` 发
  `room/follow` 事件，由房间解析目标并双向通知。
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：follow <某人>|none。\n"})
        |> prompt(CommandView, "prompt", %{})

      rest == "none" ->
        unfollow(conn)

      true ->
        conn
        |> event("room/follow", %{name: rest})
        |> assign(:prompt, false)
    end
  end

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：follow <某人>|none。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp unfollow(conn) do
    character = conn.character
    leader = character.meta.leader

    if leader do
      if Process.alive?(leader.pid) do
        send(leader.pid, %Event{
          from_pid: self(),
          topic: "follow/unregister",
          data: %{follower_id: character.id}
        })
      end

      conn
      |> put_character(%{character | meta: %{character.meta | leader: nil}})
      |> render(CommandView, "text", %{text: "Ok.\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你现在并没有跟随任何人。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end

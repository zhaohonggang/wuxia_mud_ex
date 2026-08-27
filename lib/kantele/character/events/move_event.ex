defmodule Kantele.Character.MoveEvent do
  use Kalevala.Character.Event

  require Logger

  alias Kantele.Character.CommandView
  alias Kantele.Character.MoveView

  def commit(conn, %{data: event}) do
    character = conn.character
    old_room = character.room_id

    conn = notify_enemies_left(conn, character)
    notify_followers(character, event.exit_name)
    notify_team(character, event.exit_name)

    # 先更新自身 room_id 再排队移动事件：
    # 移动事件携带的角色快照（Private.character）必须带新房间号，
    # 否则目标房间存档的玩家 room_id 是旧值，战斗同房校验会误判
    character = %{character | room_id: event.to}

    conn =
      conn
      |> put_character(character)
      |> move(:from, old_room, MoveView, "leave", %{})
      |> move(:to, event.to, MoveView, "enter", %{})
      |> unsubscribe("rooms:#{old_room}", [], &unsubscribe_error/2)
      |> subscribe("rooms:#{event.to}", [], &subscribe_error/2)
      |> event("room/look")

    conn
  end

  # 触发跟随者沿同一出口移动（Batch 5 follow）：只通知存活进程
  defp notify_followers(character, exit_name) when is_binary(exit_name) and exit_name != "" do
    followers = Map.get(character.meta, :followers, [])

    Enum.each(followers, fn follower ->
      if is_map(follower) && Process.alive?(follower.pid) do
        send(follower.pid, %Kalevala.Event{
          from_pid: self(),
          topic: "follow/move",
          data: %{exit_name: exit_name}
        })
      end
    end)
  end

  defp notify_followers(_character, _exit_name), do: :ok

  # 触发队伍成员沿同一出口移动（Batch 6 team）：队长移动时带队员
  defp notify_team(character, exit_name) when is_binary(exit_name) and exit_name != "" do
    case Map.get(character.meta, :team) do
      %{members: members} ->
        Enum.each(members, fn member ->
          if is_map(member) && member.pid != character.pid && Process.alive?(member.pid) do
            send(member.pid, %Kalevala.Event{
              from_pid: self(),
              topic: "follow/move",
              data: %{exit_name: exit_name}
            })
          end
        end)

      _ ->
        :ok
    end
  end

  defp notify_team(_character, _exit_name), do: :ok

  # 离开房间时通知自己的敌人移除自己（对应 LPC clean_up_enemy 的环境校验）
  defp notify_enemies_left(conn, character) do
    combat = character.meta.combat

    case combat do
      %Kantele.Character.Combat{} ->
        Enum.each(combat.enemies, fn enemy ->
          if Process.alive?(enemy.pid) do
            send(enemy.pid, %Kalevala.Event{
              from_pid: self(),
              topic: "combat/enemy-left",
              data: %{id: character.id}
            })
          end
        end)

      _ ->
        :ok
    end

    conn
  end

  def abort(conn, %{data: event}) do
    conn
    |> render(MoveView, "fail", event)
    |> prompt(CommandView, "prompt")
  end

  def notice(conn, %{data: event}) do
    conn
    |> assign(:character, event.character)
    |> assign(:direction, event.direction)
    |> assign(:reason, event.reason)
    |> render(MoveView, "notice")
    |> prompt(CommandView, "prompt")
  end

  def unsubscribe_error(conn, error) do
    Logger.error("Tried to unsubscribe from the old room and failed - #{inspect(error)}")

    conn
  end

  def subscribe_error(conn, error) do
    Logger.error("Tried to subscribe to the new room and failed - #{inspect(error)}")

    conn
  end
end

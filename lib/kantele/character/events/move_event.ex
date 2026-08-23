defmodule Kantele.Character.MoveEvent do
  use Kalevala.Character.Event

  require Logger

  alias Kantele.Character.CommandView
  alias Kantele.Character.MoveView

  def commit(conn, %{data: event}) do
    conn =
      notify_enemies_left(conn, conn.character)

    conn
    |> move(:from, event.from, MoveView, "leave", %{})
    |> move(:to, event.to, MoveView, "enter", %{})
    |> put_character(%{conn.character | room_id: event.to})
    |> unsubscribe("rooms:#{event.from}", [], &unsubscribe_error/2)
    |> subscribe("rooms:#{event.to}", [], &subscribe_error/2)
    |> event("room/look")
  end

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

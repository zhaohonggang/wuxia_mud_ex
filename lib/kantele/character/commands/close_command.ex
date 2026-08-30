defmodule Kantele.Character.CloseCommand do
  @moduledoc """
  关门命令：`close <门>`

  对应 LPC cmds/std/close.c
  关闭房间的门。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target}) do
    character = conn.character

    case close_door(conn.room, target, character) do
      :ok ->
        conn
        |> render(CommandView, "text", %{text: "你将#{target}关上了。\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, message} ->
        render_error(conn, message)
    end
  end

  defp close_door(room, target, _character) do
    doors = Map.get(room, :doors, %{})

    case Map.get(doors, target) do
      nil ->
        {:error, "你要关闭什么？\n"}

      door when is_map(door) ->
        if Map.get(door, :open, true) do
          :ok
        else
          {:error, "#{target}已经关上了。\n"}
        end
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

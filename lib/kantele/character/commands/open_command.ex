defmodule Kantele.Character.OpenCommand do
  @moduledoc """
  开门命令：`open <门>`

  对应 LPC cmds/std/open.c
  打开房间的门。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target}) do
    character = conn.character

    case open_door(conn.room, target, character) do
      :ok ->
        conn
        |> render(CommandView, "text", %{text: "你将#{target}打开了。\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, message} ->
        render_error(conn, message)
    end
  end

  defp open_door(room, target, _character) do
    doors = Map.get(room, :doors, %{})

    case Map.get(doors, target) do
      nil ->
        {:error, "你要打开什么？\n"}

      door when is_map(door) ->
        if Map.get(door, :open, false) do
          {:error, "#{target}已经打开了。\n"}
        else
          :ok
        end
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

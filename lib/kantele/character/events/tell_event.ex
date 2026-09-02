defmodule Kantele.Character.TellEvent do
  use Kalevala.Character.Event

  require Logger

  alias Kantele.Character.CommandView
  alias Kantele.Character.TellView

  def interested?(event) do
    match?("characters:" <> _, event.data.channel_name)
  end

  def broadcast(conn, %{data: %{character: character, text: text}}) when character != nil do
    conn
    |> put_meta(:reply_to, character.name)
    |> assign(:character, character)
    |> assign(:text, text)
    |> render(TellView, "echo")
    |> prompt(CommandView, "prompt", %{})
    |> publish_message("characters:#{character.id}", text, [], &publish_error/2)
  end

  def broadcast(conn, event) do
    conn
    |> assign(:name, event.data.name)
    |> render(TellView, "character-not-found")
    |> prompt(CommandView, "prompt", %{})
  end

  def echo(conn, event) do
    character = event.data.character

    conn
    |> maybe_put_reply_to(character)
    |> assign(:character, character)
    |> assign(:id, event.data.id)
    |> assign(:text, event.data.text)
    |> render(TellView, "listen")
    |> prompt(CommandView, "prompt", %{})
  end

  # 记录发话人，供 `reply` 命令回话。
  defp maybe_put_reply_to(conn, nil), do: conn
  defp maybe_put_reply_to(conn, character), do: put_meta(conn, :reply_to, character.name)

  def subscribe_error(conn, error) do
    Logger.error("Tried to subscribe to the new channel and failed - #{inspect(error)}")

    conn
  end

  def publish_error(conn, error) do
    Logger.error("Tried to publish to a channel and failed - #{inspect(error)}")

    conn
  end
end

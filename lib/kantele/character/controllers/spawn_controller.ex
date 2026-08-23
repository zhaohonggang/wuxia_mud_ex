defmodule Kantele.Character.SpawnController do
  use Kalevala.Character.Controller

  require Logger

  alias Kalevala.Brain
  alias Kantele.Character.MoveEvent
  alias Kantele.Character.NonPlayerEvents
  alias Kantele.Character.SpawnView
  alias Kantele.Character.TellEvent
  alias Kantele.CharacterChannel
  alias Kantele.Communication

  @impl true
  def init(conn) do
    character = conn.character

    # 启动自然回复循环（foreman 自投递）
    Kantele.Character.CombatEvent.kick_regen()

    conn =
      Enum.reduce(character.meta.initial_events, conn, fn initial_event, conn ->
        delay_event(conn, initial_event.delay, initial_event.topic, initial_event.data)
      end)

    conn
    |> move(:to, character.room_id, SpawnView, "spawn", %{})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> event("room/look", %{})
  end

  @impl true
  def event(conn, event) do
    case dead?(conn.character) do
      true ->
        # 尸体不跑行为树，安静等待 respawn
        conn

      false ->
        conn.character.brain
        |> Brain.run(conn, event)
        |> NonPlayerEvents.call(event)
    end
  end

  defp dead?(%{meta: %{combat: %Kantele.Character.Combat{dead: true}}}), do: true
  defp dead?(_), do: false

  @impl true
  def recv(conn, _text), do: conn

  @impl true
  def display(conn, _text), do: conn

  defp register_and_subscribe_character_channel(conn, character) do
    options = [character_id: character.id]

    case Communication.register("characters:#{character.id}", CharacterChannel, options) do
      :ok ->
        :ok

      {:error, :already_registered} ->
        # foreman 崩溃重启等场景下频道仍在，直接复用
        Logger.warn("Character channel already registered, reusing - #{character.id}")

        :ok

      {:error, reason} ->
        Logger.error("Failed to register character channel - #{inspect(reason)}")

        :ok
    end

    options = [character: character]
    subscribe(conn, "characters:#{character.id}", options, &TellEvent.subscribe_error/2)
  end
end

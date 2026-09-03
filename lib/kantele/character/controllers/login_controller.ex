defmodule Kantele.Character.LoginController do
  use Kalevala.Character.Controller

  require Logger

  alias ExVenture.Characters
  alias Kalevala.Character
  alias Kantele.Character.ChannelEvent
  alias Kantele.Character.CharacterView
  alias Kantele.Character.CommandController
  alias Kantele.Character.LoginView
  alias Kantele.Character.MoveEvent
  alias Kantele.Character.MoveView
  alias Kantele.Character.QuitView
  alias Kantele.Character.TellEvent
  alias Kantele.CharacterChannel
  alias Kantele.Communication

  @impl true
  def init(conn) do
    conn
    |> put_session(:login_state, :username)
    |> render(LoginView, "welcome", %{})
    |> prompt(LoginView, "name", %{})
  end

  @impl true
  def recv_event(conn, event) do
    case event.topic do
      "Login.Character" ->
        process_character_token(conn, event.data["token"])

      _ ->
        conn
    end
  end

  @impl true
  def recv(conn, ""), do: conn

  def recv(conn, data) do
    case get_session(conn, :login_state) do
      :username ->
        process_username(conn, data)

      :password ->
        process_password(conn, data)

      :character ->
        process_character(conn, data)
    end
  end

  defp process_username(conn, data) do
    name = String.trim(data)

    case name do
      "" ->
        prompt(conn, LoginView, "name", %{})

      <<4>> ->
        conn
        |> prompt(QuitView, "goodbye", %{})
        |> halt()

      "quit" ->
        conn
        |> prompt(QuitView, "goodbye", %{})
        |> halt()

      name ->
        conn
        |> put_session(:login_state, :password)
        |> put_session(:username, name)
        |> send_option(:echo, true)
        |> prompt(LoginView, "password", %{})
    end
  end

  defp process_password(conn, _data) do
    name = get_session(conn, :username)

    Logger.info("Signing in \"#{name}\"")

    conn
    |> put_session(:login_state, :character)
    |> send_option(:echo, false)
    |> render(LoginView, "signed-in", %{})
    |> prompt(LoginView, "character-name", %{})
  end

  defp process_character(conn, character_name) do
    name = String.trim(character_name)

    {loaded, wiz_level} =
      case Kantele.Character.Records.load(name) do
        {:ok, metadata, wiz_level} -> {{:ok, metadata}, wiz_level}
        :error -> {:error, 0}
      end

    character =
      name
      |> build_character()
      |> Kantele.Character.Records.apply_to_character(loaded, wiz_level)

    # 启动自然回复循环（foreman 自投递）
    Kantele.Character.CombatEvent.kick_regen()

    conn
    |> put_session(:login_state, :authenticated)
    |> put_character(character)
    |> render(CharacterView, "vitals", %{})
    |> move(:to, character.room_id, MoveView, "enter", %{})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> subscribe("general", [], &ChannelEvent.subscribe_error/2)
    |> subscribe("rumor", [], &ChannelEvent.subscribe_error/2)
    |> render(LoginView, "enter-world", %{})
    |> put_controller(CommandController)
    |> event("room/look", %{})
    |> event("inventory/list", %{})
  end

  defp process_character_token(conn, token) do
    case Phoenix.Token.verify(Web.Endpoint, "character id", token, max_age: 3600) do
      {:ok, character_id} ->
        {:ok, character} = Characters.get(character_id)

        process_character(conn, character.name)
    end
  end

  defp build_character(name) do
    starting_room_id = Kantele.World.start_room_id()

    %Character{
      id: Character.generate_id(),
      pid: self(),
      room_id: starting_room_id,
      name: name,
      status: "#{name} is here.",
      description: "#{name} is a person.",
      inventory: [
        %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: "global:potion",
          created_at: DateTime.utc_now(),
          meta: %Kantele.World.Item.Meta{}
        }
      ],
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: 100
      }
    }
  end

  defp register_and_subscribe_character_channel(conn, character) do
    options = [character_id: character.id]
    :ok = Communication.register("characters:#{character.id}", CharacterChannel, options)

    options = [character: character]
    subscribe(conn, "characters:#{character.id}", options, &TellEvent.subscribe_error/2)
  end
end

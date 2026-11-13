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
  alias Kantele.Character.SetupController
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
      |> place_on_login()

    # 启动自然回复循环（foreman 自投递）
    Kantele.Character.CombatEvent.kick_regen()

    conn =
      conn
      |> put_session(:login_state, :authenticated)
      |> put_character(character)
      |> render(CharacterView, "vitals", %{})
      |> move(:to, character.room_id, MoveView, "enter", %{})
      |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
      |> register_and_subscribe_character_channel(character)
      |> subscribe("general", [], &ChannelEvent.subscribe_error/2)
      |> subscribe("rumor", [], &ChannelEvent.subscribe_error/2)

    # 新玩家（尚未完成注册问答）：转入 SetupController 在阎罗殿走
    # 性别→洗点→投胎→赠特技 的问答，完成后其内部再转交 CommandController。
    # 老玩家（setup_done=true）直接进游戏。
    if character.meta.setup_done do
      conn
      |> render(LoginView, "enter-world", %{})
      |> put_controller(CommandController)
      |> event("room/look", %{})
      |> event("inventory/list", %{})
    else
      conn
      |> put_controller(SetupController)
    end
  end

  defp process_character_token(conn, token) do
    case Phoenix.Token.verify(Web.Endpoint, "character id", token, max_age: 3600) do
      {:ok, character_id} ->
        case Characters.get(character_id) do
          {:ok, character} ->
            process_character(conn, character.name)

          {:error, _reason} ->
            token_rejected(conn, :unknown_character)
        end

      {:error, reason} when reason in [:expired, :invalid] ->
        # 浏览器里那个 token 超过 1 小时了（调试久了就会遇到）。
        # 以前这里没有子句 -> CaseClauseError -> Foreman 崩掉 -> 玩家表现为
        # 「一登进去就断线」。现在把会话退回用户名步骤，让玩家重新登录。
        Logger.info("Character token rejected (#{reason}), returning to username prompt")

        token_rejected(conn, reason)

      {:error, reason} ->
        token_rejected(conn, reason)
    end
  end

  defp token_rejected(conn, reason) do
    conn
    |> put_session(:login_state, :username)
    |> put_session(:username, nil)
    |> send_option(:echo, true)
    |> render(LoginView, "token-expired", %{reason: reason})
    |> prompt(LoginView, "name", %{})
  end

  # 登录落点（EX-注册与转世迁移计划 Phase 0.3）：
  #
  # - 已完成注册（`meta.setup_done == true`）的玩家 → 回出生地 `env[:startroom]`；
  #   若该玩家无出生地记录（历史老玩家），沿用 build_character 的全局起始房。
  # - 新玩家（尚未完成注册问答，`setup_done != true`）→ 进入阎罗殿（BORN_ROOM）
  #   进行「洗点(washto)」与「投胎(born)」问答，与 LPC 玩家体验一致。
  #
  # 注：`setup_done` 为 DB 列、迁移时回填既有玩家为 true，故既不会误伤老玩家，
  # 也不会让新玩家跳过问答直接进游戏。
  defp place_on_login(character) do
    env = character.meta.env || %{}
    startroom = Map.get(env, :startroom)

    room_id =
      cond do
        # 幽灵态重登：直接回地府鬼门关（对齐 LPC logind.c is_ghost() → DEATH_ROOM），
        # 不走出生地，等白无常接引还阳
        Map.get(env, :ghost) == true ->
          Kantele.World.death_room_id()

        character.meta.setup_done ->
          startroom || character.room_id

        true ->
          Kantele.World.born_room_id()
      end

    %{character | room_id: room_id}
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

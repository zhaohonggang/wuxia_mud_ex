defmodule Kantele.Character.EmoteCommand do
  use Kalevala.Character.Command, dynamic: true

  alias Kantele.Character.Emotes
  alias Kantele.Character.EmoteAction
  alias Kantele.Character.EmoteView

  @impl true
  def parse(text, _opts) do
    case Emotes.get(text) do
      {:ok, command} ->
        {:dynamic, :broadcast, %{"text" => command.text}}

      {:error, :not_found} ->
        :skip
    end
  end

  # 表情名直用命令（smile/wave/frown）。
  # 不走框架 dynamic 路由：kalevala 的 parse_dynamic_text 返回 3 元组，
  # 而 Router.parse/3 只匹配 4 元组，走到那里必 CaseClauseError 崩 foreman
  def smile(conn, _params), do: named(conn, "smile")

  def wave(conn, _params), do: named(conn, "wave")

  def frown(conn, _params), do: named(conn, "frown")

  defp named(conn, command) do
    case Emotes.get(command) do
      {:ok, emote} ->
        broadcast(conn, %{"text" => emote.text})

      _ ->
        conn
    end
  end

  def broadcast(conn, params) do
    params = Map.put(params, "channel_name", "rooms:#{conn.character.room_id}")

    conn
    |> EmoteAction.run(params)
    |> assign(:prompt, false)
  end

  def list(conn, _params) do
    emotes = Enum.sort(Emotes.keys())

    render(conn, EmoteView, "list", %{emotes: emotes})
  end
end

defmodule Kantele.Character.GotoCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport

  def run(conn, %{"target" => target} = _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        case find_room(target) do
          nil ->
            return_error(conn, "找不到目标地点 #{target}。\n")

          room_id ->
            conn
            |> Teleport.teleport(room_id)
        end
    end
  end

  def run(conn, _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "用法: goto <房间ID或名称>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp find_room(target) do
    characters = Kantele.Character.Presence.characters()

    target_lower = String.downcase(target)

    if char = Enum.find(characters, &(String.downcase(&1.name) == target_lower)) do
      char.room_id
    else
      if String.contains?(target, ":") do
        if room_loaded?(target), do: target, else: nil
      else
        nil
      end
    end
  end

  # A room id that was never loaded has no registered `rooms:<id>` channel, so
  # Teleport.teleport/2 would call Communication.subscribe/3 on it.  That returns
  # the bare atom `:error` when the channel is missing from ETS
  # (Kalevala.Communication.subscribe/4), and then
  # Kalevala.Character.Foreman.Channel.handle_channel_change/3 - whose `case` only
  # matches `:ok` and `{:error, reason}` - raises CaseClauseError, killing the
  # character process.  The command's own "找不到目标地点" branch is the right
  # place to stop it, so verify the channel exists before handing the id over.
  #
  # The table is `Kantele.Communication.Channels`, not
  # `Kalevala.Communication.Channels`: Kantele.Communication sets its own
  # `channel_ets_key` via config overrides, so the module name differs even though
  # kalevala's own default points at its module.  Looking in the wrong table would
  # always answer "not loaded" and break every legal goto.
  #
  # A room that exists in data/world but whose channel has not been registered
  # yet is genuinely unreachable right now, so reporting it is correct.
  defp room_loaded?(room_id) do
    table = Kantele.Communication.Channels

    # The table is created at boot; in a bare process it may not exist yet and
    # :ets.lookup/2 raises on a missing table.
    case :ets.whereis(table) do
      :undefined ->
        false

      _tid ->
        case :ets.lookup(table, "rooms:" <> room_id) do
          [_ | _] -> true
          _ -> false
        end
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

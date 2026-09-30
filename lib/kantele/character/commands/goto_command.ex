defmodule Kantele.Character.GotoCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.World.ZoneCache

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

  # A room id that was never loaded makes Teleport.teleport/2 call
  # Communication.subscribe/3 on a channel that does not exist.
  # Kalevala.Communication.subscribe/4 then returns the bare atom `:error`, and
  # Kalevala.Character.Foreman.Channel.handle_channel_change/3 - whose `case` only
  # matches `:ok` and `{:error, reason}` - raises CaseClauseError and kills the
  # character process.  The command's own "找不到目标地点" branch is the right
  # place to stop it.
  #
  # The authority is ZoneCache, which Kantele.World.Kickoff.apply_world/3 fills
  # with every zone *before* Loader.strip_zone/1 empties their :rooms, so it holds
  # the full room list.  Two alternatives were tried and rejected:
  #   * the `rooms:<id>` channel in ETS - that table only exists once the world
  #     has been applied, so a process running before/without Kickoff sees an
  #     empty table and would reject every legal target;
  #   * `GenServer.whereis(Room.global_name(id))` - fine in production (Kickoff
  #     starts a process per room) but there is no world at all under `mix test`.
  #
  # An unknown zone is treated as "not loaded" rather than "allow": the cache is
  # populated for every converted zone at boot, so a miss means the zone does not
  # exist, and allowing it would let the crash through.
  defp room_loaded?(room_id) do
    [zone_id | _] = String.split(room_id, ":")

    case ZoneCache.get(zone_id) do
      {:ok, zone} -> Enum.any?(zone.rooms, &(&1.id == room_id))
      _ -> false
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

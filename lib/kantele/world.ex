defmodule Kantele.World do
  @moduledoc """
  GenServer to load and boot the world
  """

  use Supervisor

  alias Kantele.World.Loader
  alias Kantele.World.ZoneCache

  defstruct characters: [], items: [], rooms: [], zones: []

  @doc """
  Dereference a world variable reference
  """
  def dereference(reference) when is_binary(reference) do
    dereference(String.split(reference, "."))
  end

  def dereference([zone_id | reference]) do
    case ZoneCache.get(zone_id) do
      {:ok, zone} ->
        Loader.dereference(zone, reference)

      _ ->
        :error
    end
  end

  @doc "按房间 id 查 flags（A5/D2；查不到或格式异常返回空列表）"
  def room_flags(room_id) when is_binary(room_id) do
    zone_id =
      room_id
      |> String.split(":")
      |> hd()

    case ZoneCache.get(zone_id) do
      {:ok, zone} ->
        zone.rooms
        |> Enum.find(&(&1.id == room_id))
        |> case do
          nil ->
            []

          room ->
            flags = Map.get(room, :flags, [])
            if is_list(flags), do: flags, else: []
        end

      _ ->
        []
    end
  end

  def room_flags(_), do: []

  @doc """
  出生点房间 id（A5/D2 startroom flag）

  优先取全库第一个带 "startroom" flag 的房间；没有则回落到 config
  `player.starting_room_id`（dereference 后的 id）。
  """
  def start_room_id() do
    case start_room_from_flags() do
      nil ->
        dereference(Kantele.Config.get([:player, :starting_room_id]))

      room_id ->
        room_id
    end
  end

  defp start_room_from_flags() do
    ZoneCache.keys()
    |> Enum.sort()
    |> Enum.flat_map(fn zone_id ->
      case ZoneCache.get(zone_id) do
        {:ok, zone} -> Map.get(zone, :rooms, [])
        _ -> []
      end
    end)
    |> Enum.find_value(fn room ->
      flags = Map.get(room, :flags, [])

      if is_list(flags) and "startroom" in flags do
        room.id
      else
        nil
      end
    end)
  end

  @doc false
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    config = Application.get_env(:ex_venture, :kantele_world, [])
    kickoff = Keyword.get(config, :kickoff, true)

    children = [
      {ZoneCache, [id: ZoneCache, name: ZoneCache]},
      {Kantele.World.Items, [id: Kantele.World.Items, name: Kantele.World.Items]},
      {Kalevala.World, [name: Kantele.World]},
      {Kantele.World.Kickoff, [name: Kantele.World.Kickoff, start: kickoff]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

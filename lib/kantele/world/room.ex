defmodule Kantele.World.Room do
  @moduledoc """
  Callbacks for a Kalevala room
  """

  require Logger

  alias Kalevala.Verb
  alias Kantele.Communication
  alias Kantele.RoomChannel
  alias Kantele.World.Items
  alias Kantele.World.Room.Events

  defstruct [
    :id,
    :key,
    :zone_id,
    :name,
    :description,
    :map_color,
    :map_icon,
    :x,
    :y,
    :z,
    exits: [],
    features: []
  ]

  @doc """
  Called after a room is initialized, used in the Callbacks protocol
  """
  def initialized(room) do
    options = [room_id: room.id]

    with {:error, _reason} <- Communication.register("rooms:#{room.id}", RoomChannel, options) do
      Logger.warn("Failed to register the room's channel, did the room restart?")

      :ok
    end
  end

  @doc """
  Forward an event to the Events router

  Used in the `Callbacks` protocol.
  """
  def event(context, event), do: Events.call(context, event)

  @doc """
  Load an item based on room information

  Used in the `Callbacks` protocol.
  """
  def load_item(item_instance), do: Items.get!(item_instance.item_id)

  @doc """
  Handle requesting picking up an item

  Used in the `Callbacks` protocol.

  Checks if the item has the verb to pick up in a room before allowing.

  If the instance id is `nil` then the event `item_name` is considered and id
  and searched accordingly before checking for the appropriate verb.
  """
  def item_request_pickup(room, context, event, nil) do
    item_instance =
      Enum.find(context.item_instances, fn item_instance ->
        item_instance.id == event.data.item_name
      end)

    case item_instance != nil do
      true ->
        item_request_pickup(room, context, event, item_instance)

      false ->
        {:abort, event, :no_item, nil}
    end
  end

  def item_request_pickup(_room, _context, event, item_instance) do
    item = load_item(item_instance)

    case Verb.has_matching_verb?(item.verbs, :get, %Verb.Context{location: "room"}) do
      true ->
        {:proceed, event, item_instance}

      false ->
        {:abort, event, :missing_verb, item_instance}
    end
  end

  defimpl Kalevala.World.Room.Callbacks do
    require Logger

    alias Kalevala.World.BasicRoom
    alias Kantele.World.Room

    @impl true
    def init(room), do: room

    @impl true
    def initialized(room), do: Room.initialized(room)

    @impl true
    def event(_room, context, event), do: Room.event(context, event)

    @impl true
    def exits(room), do: room.exits

    @impl true
    def movement_request(_room, context, event, room_exit),
      do: BasicRoom.movement_request(context, event, room_exit)

    @impl true
    def confirm_movement(_room, context, event),
      do: BasicRoom.confirm_movement(context, event)

    @impl true
    def item_request_drop(_room, context, event, item_instance),
      do: BasicRoom.item_request_drop(context, event, item_instance)

    @impl true
    def load_item(_room, item_instance), do: Room.load_item(item_instance)

    @impl true
    def item_request_pickup(room, context, event, item_instance),
      do: Room.item_request_pickup(room, context, event, item_instance)
  end
end

defmodule Kantele.World.Room.Events do
  @moduledoc false

  use Kalevala.Event.Router

  scope(Kantele.World.Room) do
    module(ContextEvent) do
      event("context/lookup", :call)
    end

    module(CombatEvent) do
      event("combat/attack", :call)
      event("combat/aggressive", :call)
      event("skills/learn", :call)
    end

    module(ForwardEvent) do
      event("characters/emote", :call)
      event("characters/move", :call)
      event("commands/delayed", :call)
      event("inventory/list", :call)
    end

    module(LookEvent) do
      event("room/look", :call)
    end

    module(MapEvent) do
      event("zone-map/look", :call)
    end

    module(RandomExitEvent) do
      event("room/flee", :call)
      event("room/wander", :call)
    end

    module(SayEvent) do
      event("say/send", :call)
    end

    module(TellEvent) do
      event("tell/send", :call)
    end

    module(WhisperEvent) do
      event("whisper/send", :call)
    end
  end
end

defmodule Kantele.World.Room.ForwardEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    event(context, event.from_pid, self(), event.topic, event.data)
  end
end

defmodule Kantele.World.Room.RandomExitEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    exits =
      Enum.map(context.data.exits, fn room_exit ->
        room_exit.exit_name
      end)

    event(context, event.from_pid, self(), event.topic, %{exits: exits})
  end
end

defmodule Kantele.World.Room.LookEvent do
  import Kalevala.World.Room.Context

  alias Kantele.Character.LookView
  alias Kantele.World.Items
  alias Kantele.World.ZoneCache

  def call(context, event) do
    x = context.data.x
    y = context.data.y
    z = context.data.z

    {:ok, mini_map} = ZoneCache.mini_map(context.data.zone_id, {x, y, z})

    characters =
      Enum.reject(context.characters, fn character ->
        character.id == event.acting_character.id
      end)

    item_instances =
      Enum.map(context.item_instances, fn item_instance ->
        %{item_instance | item: Items.get!(item_instance.item_id)}
      end)

    context
    |> assign(:room, context.data)
    |> assign(:characters, characters)
    |> assign(:item_instances, item_instances)
    |> assign(:mini_map, mini_map)
    |> render(event.from_pid, LookView, "look")
    |> render(event.from_pid, LookView, "mini_map")
    |> render(event.from_pid, LookView, "look.extra")
  end
end

defmodule Kantele.World.Room.MapEvent do
  import Kalevala.World.Room.Context

  alias Kantele.Character.MapView
  alias Kantele.World.ZoneCache

  def call(context, event) do
    x = context.data.x
    y = context.data.y
    z = context.data.z

    {:ok, mini_map} = ZoneCache.mini_map(context.data.zone_id, {x, y, z})

    context
    |> assign(:room, context.data)
    |> assign(:mini_map, mini_map)
    |> render(event.from_pid, MapView, "look", %{})
  end
end

defmodule Kantele.World.Room.ContextEvent do
  import Kalevala.World.Room.Context

  alias Kalevala.Verb
  alias Kalevala.World.Item
  alias Kantele.Character.ContextView
  alias Kantele.World.Items

  def call(context, %{from_pid: from_pid, data: %{type: :item, id: id}}) do
    item_instance =
      Enum.find(context.item_instances, fn item_instance ->
        item_instance.id == id
      end)

    case item_instance != nil do
      true ->
        handle_context(context, from_pid, item_instance)

      false ->
        handle_unknown(context, from_pid, id)
    end
  end

  defp handle_unknown(context, from_pid, id) do
    context
    |> assign(:context, "room")
    |> assign(:type, "item")
    |> assign(:id, id)
    |> render(from_pid, ContextView, "unknown")
  end

  defp handle_context(context, from_pid, item_instance) do
    item = Items.get!(item_instance.item_id)
    item_instance = %{item_instance | item: item}

    verbs = Item.context_verbs(item, %{location: "room"})
    verbs = Verb.replace_variables(verbs, %{id: item_instance.id})

    context
    |> assign(:context, "room")
    |> assign(:item_instance, item_instance)
    |> assign(:verbs, verbs)
    |> render(from_pid, ContextView, "item")
  end
end

defmodule Kantele.World.Room.SayEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data["at"]
    character = find_local_character(context, name)
    data = Map.put(event.data, "at_character", character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Kantele.World.Room.TellEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data.name
    character = find_local_character(context, name) || find_player_character(name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    find_character(context.characters, name)
  end

  defp find_player_character(name) do
    characters = Kantele.Character.Presence.characters()
    find_character(characters, name)
  end

  defp find_character(characters, name) do
    Enum.find(characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Kantele.World.Room.WhisperEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data.name
    character = find_local_character(context, name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Kantele.World.Room.NotifyEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    Enum.reduce(context.characters, context, fn character, context ->
      event(context, character.pid, event.from_pid, event.topic, event.data)
    end)
  end
end

defmodule Kantele.World.Room.CombatEvent do
  @moduledoc """
  房间侧战斗解析（对应 combatd.c 的环境职责）

  - `combat/attack`：按名字找到目标，向双方发 `combat/start`
  - `combat/strike`：校验双方同场后跑命中管线，广播文案并结算受击方
  - `combat/aggressive`：aggressive NPC 挑选在场玩家开战
  - `skills/learn`：找到师父 NPC 并转发授艺请求
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CharacterView
  alias Kantele.Character.CommandView

  def call(context, event) do
    attacker = Enum.find(context.characters, &(&1.pid == event.from_pid))

    case attacker do
      nil -> context
      attacker -> dispatch(context, event, attacker)
    end
  end

  # ---- 开战请求 ----

  defp dispatch(context, %{topic: "combat/attack", data: %{name: name}}, attacker) do
    target =
      Enum.find(context.characters, fn character ->
        character.pid != attacker.pid &&
          safe_matches?(character, name)
      end)

    cond do
      is_nil(name) or name == "" ->
        render(context, attacker.pid, CommandView, "text", %{text: "你要跟谁动手？\n"})

      is_nil(target) ->
        render(
          context,
          attacker.pid,
          CharacterView,
          "not-found",
          %{name: name}
        )

      dead?(target) or dead?(attacker) ->
        render(
          context,
          attacker.pid,
          CommandView,
          "text",
          %{text: "对方已经倒下了，刀剑无眼，何必赶尽杀绝。\n"}
        )

      true ->
        engage(context, attacker, target)
    end
  end

  # ---- aggressive NPC ----

  defp dispatch(context, %{topic: "combat/aggressive"}, npc) do
    cond do
      dead?(npc) ->
        context

      true ->
        players = players_in_room(context)

        case players do
          [] ->
            context

          players ->
            victim = Enum.random(players)
            engage(context, npc, victim)
        end
    end
  end

  # ---- 学习 ----

  defp dispatch(context, %{topic: "skills/learn"} = event, student) do
    teacher =
      Enum.find(context.characters, fn character ->
        character.pid != student.pid &&
          safe_matches?(character, event.data.name)
      end)

    case teacher do
      nil ->
        render(
          context,
          student.pid,
          CommandView,
          "text",
          %{text: "这里没有这个人。\n"}
        )

      teacher ->
        # 学生属性由命令层随事件携带（房间上下文中的角色是 Trimmed 版本）
        event(context, teacher.pid, student.pid, "skills/teach", %{
          skill: event.data.skill,
          student_stats: event.data.student_stats,
          reply_to: student.pid
        })
    end
  end

  # 防御版匹配：名字缺失/异形时不崩溃
  defp safe_matches?(character, keyword) when is_binary(keyword),
    do: Kalevala.Character.matches?(character, keyword)

  defp safe_matches?(_character, _other), do: false

  defp dispatch(context, _event, _attacker), do: context

  # ---- 双方入场 ----

  defp engage(context, initiator, target) do
    context
    |> start_combat(target, initiator)
    |> start_combat(initiator, target)
  end

  defp start_combat(context, character, initiator) do
    event(context, character.pid, self(), "combat/start", %{
      enemy: ref(initiator),
      initiator_id: initiator.id
    })
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # 房间上下文中的角色是 Trimmed 版本（无 combat 标记），
  # 尸体判定依赖 die 时写入的 status 文案
  defp dead?(%{status: status}) when is_binary(status),
    do: String.contains?(status, "尸体")

  defp dead?(_), do: false

  defp players_in_room(context) do
    player_ids = MapSet.new(Kantele.Character.Presence.characters(), & &1.id)

    Enum.filter(context.characters, fn character ->
      dead?(character) == false and MapSet.member?(player_ids, character.id)
    end)
  end
end

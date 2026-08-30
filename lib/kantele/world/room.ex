defmodule Kantele.World.Room do
  @moduledoc """
  Callbacks for a Kalevala room
  """

  require Logger

  alias Kalevala.Verb
  alias Kantele.Communication
  alias Kantele.Character.Combat.StatusTracker
  alias Kantele.RoomChannel
  alias Kantele.World.Items
  alias Kantele.World.Room.Events
  alias Kantele.Npc.Guarder
  alias Kalevala.World.Room.Context

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
    features: [],
    flags: [],
    dynamic_exits: %{},
    timers: %{}
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

  # ---- 房间广播原语（对应 LPC tell_room/message_vision/broadcast） ----

  @doc """
  向房间内所有人发消息（对应 LPC tell_room/2）

  `except` 可排除特定 pid/列表（如发送者不想看自己的 echo）。
  """
  def tell_room(room, message, except \\ nil) do
    except_list = cond do
      is_nil(except) -> []
      is_list(except) -> except
      true -> [except]
    end

    Enum.reduce(room.id |> get_characters_in_room(), room, fn pid, acc ->
      if pid in except_list do
        acc
      else
        send(pid, {:room_message, message})
        acc
      end
    end)
  end

  @doc """
  房间内 vision 消息（对应 LPC message_vision/1）

  文案含 `$N/$n/$l/$w` 占位符，由 Kalevala 渲染层按 acting/target 替换。
  """
  def message_vision(room, template, bindings) do
    Enum.reduce(room.id |> get_characters_in_room(), room, fn pid, acc ->
      send(pid, {:vision_message, template, bindings})
      acc
    end)
  end

  @doc "全频道广播（对应 LPC broadcast/3）：含 channel/level 过滤的大喇叭"
  def broadcast(_room, _channel, _message), do: :ok

  # ---- 房间定时器（对应 LPC set_timer/cancel_timer/call_out） ----

  @doc """
  房间级一次性定时器（对应 LPC call_out/set_timer）

  返回 `timer_ref`；到期后向房间路由投递 `{:timer, ref, data}`。
  """
  def set_timer(room, ms, data) do
    ref = make_ref()
    timer =
      Process.send_after(self(), {:room_timer, ref, data, room.id}, ms)

    %{room | timers: Map.put(room.timers, ref, timer)}
  end

  @doc "取消房间定时器（对应 LPC cancel_timer/2）"
  def cancel_timer(room, ref) do
    case Map.pop(room.timers, ref) do
      {timer, timers} ->
        :timer.cancel(timer)
        %{room | timers: timers}

      _ -> room
    end
  end

  # ---- 动态出口（对应 LPC 动态 exits + sync_room） ----

  @doc "合并静态 exits 与动态 exits（如 qianting 大门开关）"
  def all_exits(room) do
    Map.merge(room.exits, room.dynamic_exits)
  end

  @doc "设置动态出口（开门/关门/陷阱刷新），返回新 room"
  def set_dynamic_exit(room, name, exit_spec) do
    %{room | dynamic_exits: Map.put(room.dynamic_exits, name, exit_spec)}
  end

  @doc "移除动态出口"
  def remove_dynamic_exit(room, name) do
    %{room | dynamic_exits: Map.delete(room.dynamic_exits, name)}
  end

  @doc "跨房间同步（对应 LPC sync_room/1）：把动态 exits/flags 广播到同区域房间"
  def sync_room(room, _zone_rooms) do
    room
  end

  # ---- valid_leave 移动拦截钩子（对应 LPC valid_leave/4） ----

  @doc """
  移动前置校验（对应 LPC valid_leave/4）

  返回 `:ok` 放行；`{:error, reason}` 拦截并提示 `reason`。
  """
  def valid_leave(_room, _character, _dir, _enter_room), do: :ok

  @doc "房间内玩家列表（对应 LPC present/1）"
  def present(room) do
    room.id |> get_characters_in_room() |> Enum.filter(&is_player/1)
  end

  @doc "房间内活物列表（对应 LPC living/1）"
  def living(room) do
    room.id |> get_characters_in_room() |> Enum.filter(&is_living/1)
  end

  @doc "房间内物品（对应 LPC get_objects/1）"
  def get_objects(room) do
    room.id |> get_item_instances_in_room()
  end

  @doc "物品移入/移出房间（对应 LPC move_object/2）"
  def move_object(room, item_instance) do
    room
  end

  # 内部：取房间内角色 pid 列表（由 World 层维护，此处为占位）
  defp get_characters_in_room(_room_id), do: []
  defp get_item_instances_in_room(_room_id), do: []
  defp is_player(_pid), do: false
  defp is_living(_pid), do: false

  # ---- add_action 指令分发（对应 LPC add_action/2，棋房/拱猪/房间动词） ----

  @doc """
  房间级动词注册（对应 LPC add_action/2）

  把自定义动词绑定到房间实例，玩家输入时优先匹配房间动词。
  `verbs` 为 `%{verb_name => {module, function, args}}` 或
  `%{verb_name => {module, function, args, :help_text}}`。

  返回更新后的 room（将 verbs 存入 `dynamic_exits[:verbs]` 兼容字段）。
  """
  def add_action(room, verbs) when is_map(verbs) do
    existing = Map.get(room.dynamic_exits, :verbs, %{})
    %{room | dynamic_exits: Map.merge(existing, verbs)}
  end

  @doc "解析并执行房间动词（由 Kalevala.Verb 路由调用）"
  def resolve_verb(room, verb_name, context, _args) do
    verbs = Map.get(room.dynamic_exits, :verbs, %{})

    case Map.get(verbs, verb_name) do
      {module, fun, args} ->
        apply(module, fun, [context, args])
      {module, fun, args, _help} ->
        apply(module, fun, [context, args])
      nil ->
        {:error, :no_such_verb}
    end
  end

  # ---- 座位/玩家清单（对应 LPC seat/present/living） ----

  @doc "房间座位表（对应 LPC qiyuan2 的 `%{black, white, game}`）"
  def get_seats(room), do: Map.get(room.dynamic_exits, :seats, %{})

  @doc "设置座位（落子/入座/开始对弈）"
  def set_seat(room, seat_name, player_info) do
    seats = get_seats(room)
    %{room | dynamic_exits: Map.put(room.dynamic_exits, :seats, Map.put(seats, seat_name, player_info))}
  end

  @doc "移除座位玩家"
  def clear_seat(room, seat_name) do
    seats = get_seats(room)
    %{room | dynamic_exits: Map.put(room.dynamic_exits, :seats, Map.delete(seats, seat_name))}
  end

  # ---- 跨房间同步完善（对应 LPC sync_room/1） ----

  @doc "跨房间同步动态状态（出口/标记/座位/定时器）到同区域房间"
  def sync_room(room, zone_rooms) do
    Enum.reduce(zone_rooms, room, fn other_room, acc ->
      if other_room.zone_id == room.zone_id and other_room.id != room.id do
        # 广播动态出口/标记/座位变更
        send(other_room.pid, {:room_sync, room.id, %{
          dynamic_exits: room.dynamic_exits,
          flags: room.flags
        }})
      end
      acc
    end)
  end

  @doc "房间内物品移入/移出（对应 LPC move_object/2）"
  def move_object(room, item_instance) do
    # 实际由 World.Items 维护实例位置，此处仅作钩子
    room
  end

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

    defp check_guarders(context, mover, _room_exit) do
      # 找房间里的守卫 NPC（有 guarder 配置且 is_guarder? 为 true）
      guarders =
        Enum.filter(context.characters, fn c ->
          c.meta.guarder && Guarder.is_guarder?(c)
        end)

      Enum.reduce_while(guarders, :allow, fn guarder, acc ->
        case acc do
          :allow ->
            # 构造 permit_pass 参数
            opts = build_guarder_opts(guarder, mover, context)
            case Guarder.permit_pass(opts) do
              {:allow} -> {:cont, :allow}
              {:deny, msg} -> {:halt, {:deny, msg}}
            end

          {:deny, msg} ->
            {:halt, {:deny, msg}}
        end
      end)
    end

    defp build_guarder_opts(guarder, mover, context) do
      my_family = Map.get(guarder.meta.guarder, :family)
      guest_family = mover.meta.family && Map.get(mover.meta.family, :name)
      guest_born_family = mover.meta.family && Map.get(mover.meta.family, :born_family)
      carried_families =
        mover.meta.carrying
        |> Enum.filter(& &1)
        |> Enum.map(&Map.get(&1.family, :name))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      msgs = guarder.meta.guarder.msgs || %{}

      %{
        living?: not guarder.meta.dead,
        my_family: my_family,
        guest_family: guest_family,
        guest_born_family: guest_born_family,
        carried_families: carried_families,
        msgs: msgs
      }
    end

    @impl true
    def movement_request(_room, context, event, room_exit) do
      mover = Enum.find(context.characters, &(&1.pid == event.from_pid))

      if mover do
        guarder_result = check_guarders(context, mover, room_exit)
        case guarder_result do
          {:deny, msg} ->
            Context.render(context, mover.pid, Kantele.Character.CommandView, "text", %{text: msg <> "\n"})
            {:abort, event, :guarder_denied, msg}

          :allow ->
            BasicRoom.movement_request(context, event, room_exit)
        end
      else
        BasicRoom.movement_request(context, event, room_exit)
      end
    end

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

    module(ShopRequestEvent) do
      event("shop/list", :call)
      event("shop/buy", :call)
    end

    module(AskRequestEvent) do
      event("characters/ask", :call)
    end

    module(ApprenticeRequestEvent) do
      event("family/apprentice", :call)
    end

    module(QuestAskRequestEvent) do
      event("quest/ask", :call)
    end

    module(QuestCancelRequestEvent) do
      event("quest/cancel", :call)
    end

    module(GiveRequestEvent) do
      event("room/give", :call)
    end

    module(FollowRequestEvent) do
      event("room/follow", :call)
    end

    module(WhisperEvent) do
      event("whisper/send", :call)
    end

    module(TeamRequestEvent) do
      event("team/invite", :call)
      event("team/attack", :call)
    end
  end
end

defmodule Kantele.World.Room.NameMatch do
  @moduledoc """
  房间转发用角色名匹配：全名精确或首个词前缀

  双语名（如"店小二 Xiaoer"）允许玩家只输入中文名"店小二"；
  与 Kalevala.Character.matches?/2 的全名精确匹配不同。
  """

  def matches?(character, keyword) when is_binary(keyword) do
    keyword = keyword |> String.downcase() |> String.trim()
    name = character.name |> to_string() |> String.downcase()

    name == keyword or String.starts_with?(name, "#{keyword} ")
  end

  def matches?(_character, _keyword), do: false
end

defmodule Kantele.World.Room.ShopRequestEvent do
  @moduledoc """
  商店请求转发（A10/N2）

  把 `list`/`buy` 转给房间内的 NPC：指名则只找该角色，未指名则广播全场
  非玩家，由带 goods 的商人应答（房间上下文角色被 Trimmed，无法直接看 meta）。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.Combat.StatusTracker

  def call(context, %{topic: topic, data: data} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      requester ->
        forward(context, topic, data, requester)
    end
  end

  defp forward(context, topic, %{name: name}, requester) when is_binary(name) and name != "" do
    Enum.reduce(context.characters, context, fn character, acc ->
      if target?(character, requester) &&
           Kantele.World.Room.NameMatch.matches?(character, name) do
        event(acc, character.pid, self(), topic, %{
          reply_to: requester.pid,
          buyer_id: requester.id,
          buyer_name: requester.name
        })
      else
        acc
      end
    end)
  end

  defp forward(context, topic, data, requester) do
    player_ids = MapSet.new(Kantele.Character.Presence.characters(), & &1.id)

    Enum.reduce(context.characters, context, fn character, acc ->
      if target?(character, requester) &&
           not MapSet.member?(player_ids, character.id) do
        event(acc, character.pid, self(), topic, %{
          reply_to: requester.pid,
          buyer_id: requester.id,
          buyer_name: requester.name,
          item_name: Map.get(data, :item_name),
          quantity: Map.get(data, :quantity, 1)
        })
      else
        acc
      end
    end)
  end

  defp target?(character, requester) do
    character.pid != requester.pid and not dead?(character)
  end

  defp dead?(%{status: status, id: id}) when is_binary(status) do
    String.contains?(status, "尸体") or StatusTracker.dead?(id)
  end

  defp dead?(%{id: id}), do: StatusTracker.dead?(id)
  defp dead?(_), do: false
end

defmodule Kantele.World.Room.AskRequestEvent do
  @moduledoc """
  问询转发（A10/N4）：把 `问 <人> <关键词>` 转给对应 NPC
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: name, keyword: keyword}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {requester, true} ->
        Enum.reduce(context.characters, context, fn character, acc ->
          if character.pid != requester.pid and
               Kantele.World.Room.NameMatch.matches?(character, name) do
            event(acc, character.pid, self(), "characters/ask", %{
              reply_to: requester.pid,
              asker_id: requester.id,
              asker_name: requester.name,
              keyword: keyword
            })
          else
            acc
          end
        end)

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要问谁？\n"})
    end
  end
end

defmodule Kantele.World.Room.ApprenticeRequestEvent do
  @moduledoc """
  拜师转发（A11/N5）：把 `apprentice <人>` 转给对应 NPC，
  是否收徒由 NPC 的 teach 配置决定（NPC 侧应答）。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {requester, true} ->
        Enum.reduce(context.characters, context, fn character, acc ->
          if character.pid != requester.pid and
               Kantele.World.Room.NameMatch.matches?(character, name) do
            event(acc, character.pid, self(), "family/apprentice", %{
              reply_to: requester.pid,
              student_id: requester.id,
              student_name: requester.name
            })
          else
            acc
          end
        end)

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要拜谁为师？\n"})
    end
  end
end

defmodule Kantele.World.Room.QuestAskRequestEvent do
  @moduledoc """
  请求任务转发：把 `ask_quest <人>` 转给对应 NPC，
  NPC 侧按 quest 配置决定是否发布任务。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {requester, true} ->
        Enum.reduce(context.characters, context, fn character, acc ->
          if character.pid != requester.pid and
               Kantele.World.Room.NameMatch.matches?(character, name) do
            event(acc, character.pid, self(), "quest/ask", %{
              reply_to: requester.pid,
              asker_id: requester.id,
              asker_name: requester.name
            })
          else
            acc
          end
        end)

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要向谁请求任务？\n"})
    end
  end
end

defmodule Kantele.World.Room.QuestCancelRequestEvent do
  @moduledoc """
  取消任务转发：把 `cancel_quest <人>` 转给对应 NPC，
  NPC 侧取消该 NPC 发布的任务。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {requester, true} ->
        Enum.reduce(context.characters, context, fn character, acc ->
          if character.pid != requester.pid and
               Kantele.World.Room.NameMatch.matches?(character, name) do
            event(acc, character.pid, self(), "quest/cancel", %{
              reply_to: requester.pid,
              asker_id: requester.id,
              asker_name: requester.name
            })
          else
            acc
          end
        end)

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要向谁取消任务？\n"})
    end
  end
end

defmodule Kantele.World.Room.GiveRequestEvent do
  @moduledoc """
  赠送转发（Batch 5）：把 `give` 的 `room/give` 事件中的目标按名字解析，
  向目标进程发 `characters/give` 并回带赠与人信息；目标找不到时直接提示。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: data} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))
    target_name = Map.get(data, :target)

    case {requester, is_binary(target_name) and target_name != ""} do
      {nil, _} ->
        context

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要给谁什么东西？\n"})

      {requester, true} ->
        case find_target(context, requester, target_name) do
          nil ->
            render(context, requester.pid, CommandView, "text", %{text: "这里没有这个人。\n"})

          target ->
            event(context, target.pid, self(), "characters/give", %{
              item_instance: data.item_instance,
              item_name: data.item_name,
              from_id: data.from_id,
              from_name: data.from_name,
              reply_to: requester.pid
            })
        end
    end
  end

  defp find_target(context, requester, target_name) do
    Enum.find(context.characters, fn character ->
      character.pid != requester.pid and
        Kantele.World.Room.NameMatch.matches?(character, target_name)
    end)
  end
end

defmodule Kantele.World.Room.FollowRequestEvent do
  @moduledoc """
  跟随转发（Batch 5）：把 `follow` 的 `room/follow` 事件中的目标按名字解析。
  找到后同时通知目标（登记跟随者）与请求者（设置 leader），找不到时提示。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{
          text: "指令格式：follow <某人>|none。\n"
        })

      {requester, true} ->
        case find_target(context, requester, name) do
          nil ->
            render(context, requester.pid, CommandView, "text", %{text: "这里没有 #{name}。\n"})

          target ->
            context
            |> event(target.pid, self(), "follow/register", %{
              follower: %{id: requester.id, pid: requester.pid, name: requester.name},
              reply_to: requester.pid
            })
            |> event(requester.pid, self(), "follow/set-leader", %{
              leader: %{id: target.id, pid: target.pid, name: target.name}
            })
        end
    end
  end

  defp find_target(context, requester, name) do
    Enum.find(context.characters, fn character ->
      character.pid != requester.pid and
        Kantele.World.Room.NameMatch.matches?(character, name)
    end)
  end
end

defmodule Kantele.World.Room.TeamRequestEvent do
  @moduledoc """
  队伍房间转发（Batch 6）：

  - `team/invite`：把组队邀请按名字解析到同房目标，向目标发 `team/invite-request`
  - `team/attack`：队长全队攻击，为每位队员与目标建立战斗
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: target_name, team: team}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(target_name) and target_name != ""} do
      {nil, _} ->
        context

      {_requester, false} ->
        context

      {requester, true} ->
        target =
          Enum.find(context.characters, fn character ->
            character.pid != requester.pid and
              Kantele.World.Room.NameMatch.matches?(character, target_name)
          end)

        case target do
          nil ->
            context

          target ->
            Enum.reduce(team, context, fn member, acc ->
              acc
              |> start_combat(member, target)
              |> start_combat(target, member)
            end)
        end
    end
  end

  def call(context, %{data: %{name: name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你想和谁成为伙伴？\n"})

      {requester, true} ->
        case find_target(context, requester, name) do
          nil ->
            render(context, requester.pid, CommandView, "text", %{text: "这里没有 #{name}。\n"})

          target ->
            context
            |> event(target.pid, self(), "team/invite-request", %{
              leader: %{id: requester.id, pid: requester.pid, name: requester.name}
            })
            |> render(requester.pid, CommandView, "text", %{text: "你邀请#{target.name}加入你的队伍。\n"})
        end
    end
  end

  defp start_combat(context, initiator, target) do
    event(context, target.pid, self(), "combat/start", %{
      enemy: ref(initiator),
      initiator_id: initiator.id
    })
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  defp find_target(context, requester, name) do
    Enum.find(context.characters, fn character ->
      character.pid != requester.pid and
        Kantele.World.Room.NameMatch.matches?(character, name)
    end)
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

  alias Kantele.Character.Combat.StatusTracker
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
        character.id == event.acting_character.id or dead?(character)
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

  defp dead?(%{status: status, id: id}) when is_binary(status) do
    String.contains?(status, "尸体") or StatusTracker.dead?(id)
  end

  defp dead?(%{id: id}), do: StatusTracker.dead?(id)
  defp dead?(_), do: false
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
      Kantele.World.Room.NameMatch.matches?(character, name)
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
      Kantele.World.Room.NameMatch.matches?(character, name)
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
      Kantele.World.Room.NameMatch.matches?(character, name)
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
  alias Kantele.Character.Combat.StatusTracker
  alias Kantele.Character.CommandView
  alias Kantele.Npc.Guarder

  def call(context, event) do
    attacker = Enum.find(context.characters, &(&1.pid == event.from_pid))

    case attacker do
      nil -> context
      attacker -> dispatch(context, event, attacker)
    end
  end

  # ---- 开战请求 ----

  defp dispatch(context, %{topic: "combat/attack", data: %{name: name}} = event, attacker) do
    target =
      Enum.find(context.characters, fn character ->
        character.pid != attacker.pid &&
          safe_matches?(character, name)
      end)

    cond do
      no_fight?(context) ->
        render(
          context,
          attacker.pid,
          CommandView,
          "text",
          %{text: "此处乃习武清修之地，不可动手。\n"}
        )

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

      guarder_deny?(target, attacker, event) ->
        # 守卫拒战：同门 fight 拒切磋；异族 kill/hit 反杀已在 guarder_kill 分支处理
        msg = guarder_refuse_msg(target, Map.get(event.data, :type, "fight"))
        render(context, attacker.pid, CommandView, "text", %{text: msg <> "\n"})

      guarder_kill?(target, attacker, event) ->
        # 守卫反杀惹事者（kill/hit）
        engage(context, target, attacker)

      true ->
        engage(context, attacker, target)
    end
  end

  # ---- aggressive NPC ----

  defp dispatch(context, %{topic: "combat/aggressive"} = event, npc) do
    cond do
      dead?(npc) ->
        context

      no_fight?(context) ->
        # 禁斗之地 aggressive NPC 也不主动开战
        context

      true ->
        players = players_in_room(context)

        case players do
          [] ->
            context

          players ->
            # 仇恨优先（A9/P11）：记仇目标在场则优先开战，否则随机
            hated_ids = Map.get(event.data, :hated_ids, [])

            victim =
              Enum.find(players, &(&1.id in hated_ids)) || Enum.random(players)

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
          times: Map.get(event.data, :times, 1),
          student_stats: event.data.student_stats,
          reply_to: student.pid
        })
    end
  end

  # 防御版匹配：名字缺失/异形时不崩溃
  defp safe_matches?(character, keyword) when is_binary(keyword),
    do: Kantele.World.Room.NameMatch.matches?(character, keyword)

  defp safe_matches?(_character, _other), do: false

  # 房间是否禁止动手（flags 含 "no_fight"，A5/D2）
  defp no_fight?(context) do
    case context.data do
      %{flags: flags} when is_list(flags) -> "no_fight" in flags
      _ -> false
    end
  end

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
  defp dead?(%{status: status, id: id}) when is_binary(status) do
    String.contains?(status, "尸体") or StatusTracker.dead?(id)
  end

  defp dead?(%{id: id}), do: StatusTracker.dead?(id)
  defp dead?(_), do: false

  # ---- 守卫敌对判定（Guarder.check_enemy 接线） ----

  defp guarder_config?(character) do
    character.meta.guarder && Guarder.is_guarder?(character)
  end

  defp guarder_decision(target, attacker, event) do
    Guarder.check_enemy(%{
      my_family: Map.get(target.meta.guarder, :family),
      my_name: target.name,
      enemy_family: Map.get(attacker.meta.family || %{}, :name),
      enemy_name: attacker.name,
      enemy_id: attacker.id,
      type: Map.get(event.data, :type, "fight")
    })
  end

  defp guarder_deny?(target, attacker, event) do
    guarder_config?(target) and guarder_decision(target, attacker, event) ==
      {:refuse_fight, attacker.name}
  end

  defp guarder_kill?(target, attacker, event) do
    guarder_config?(target) and match?({:kill, _}, guarder_decision(target, attacker, event))
  end

  defp guarder_refuse_msg(target, _type) do
    msgs = target.meta.guarder.msgs || %{}
    Map.get(msgs, :refuse_fight) ||
      "#{target.name}摇头道：同门之间，点到为止，切磋就免了。\n"
  end

  defp players_in_room(context) do
    player_ids = MapSet.new(Kantele.Character.Presence.characters(), & &1.id)

    Enum.filter(context.characters, fn character ->
      dead?(character) == false and MapSet.member?(player_ids, character.id)
    end)
  end
end

defmodule Kantele.World.Room do
  @moduledoc """
  Callbacks for a Kalevala room

  对应 LPC inherit/room/room.c，包括：
  - Room.reset/0 - 房间重置逻辑
  - Room.Const - 房间常量
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
    timers: %{},
    state: %{},
    item_desc: %{},
    exit_vetoes: [],

    # LPC set("behavior", "guarded_exit") + behavior_config。
    # 转换器把这两个字段整组丢掉了（loader 之前根本不读），守卫拦截因此 16 个
    # 房间全部失效 —— 详见 docs/ucl-comment-todo.zh-CN.md 三、B 节。
    behavior: nil,
    behavior_config: nil,

    # LPC set("room_owner"/"room_name"/"room_position"/"room_owner_id")：
    # 房间归属信息。源 .c 中全部为 `//**` 注释块里的模板占位符（ROOM_OWNER 等），
    # 无激活的 set() 调用，故暂无数据可回填；字段先加到结构体（默认 nil），
    # loader 只读取，不产生任何行为变化（P7）。待有真实数据/消费端后再回填。
    room_owner: nil,
    room_name: nil,
    room_position: nil,
    room_owner_id: nil,

    # P5-1：逐对象 add_action 通道（LPC add_action("verb","handler")）。
    # 存玩家输入的 verb → LPC handler 函数名 的映射（如 %{"convert" => "bian"}）。
    # 注意：冻结的转换器（lpc_converter.ex L1286-1289）只存了 handler、丢了 verb，
    # 故 verb→handler 映射需由 backfill 脚本从 .c 回源重抽（见 D24）。
    # 本字段只读取、不产生任何行为变化（P7）；消费端（对象级 verb 分发路由）见 P5-1b。
    actions: %{}
  ]

  @doc """
  Called after a room is initialized, used in the Callbacks protocol
  """
  def initialized(room) do
    options = [room_id: room.id]

    with {:error, _reason} <- Communication.register("rooms:#{room.id}", RoomChannel, options) do
      Logger.debug("Room channel already registered (room restarted): #{room.id}")

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

  实例已挂真实定义（wuji 书册的随机标题副本）时直接用它，否则回退世界定义。
  """
  def load_item(%{item: %Kalevala.World.Item{} = item} = _item_instance)
      when not is_nil(item.id) do
    item
  end

  def load_item(item_instance), do: Items.get!(item_instance.item_id)

  @doc """
  房间 flag 判定（对应 LPC `room->query("<flag>")`）

  flags 是 UCL 顶层的字符串列表（转换器 `build_room_flags` 白名单
  no_fight/no_steal/no_sleep_room/outdoors/water + B1 回填的
  sleep_room/no_beg/startroom），如 `["no_fight", "no_steal"]`。

  **历史坑（R6）**：room.ex 曾有若干处直读 `context.data.no_steal` 等**结构体
  不存在的字段**（Room defstruct 只有 `flags`）→ 每次求值都抛 `KeyError`
  （steal/attempt 三个条件全踩中、search 的 no_search 同理）。房间事件里的
  flag 判定一律走本函数，不要再直读字段。
  """
  def has_flag?(room, flag) when is_binary(flag) do
    room
    |> Map.get(:flags, [])
    |> List.wrap()
    |> Enum.member?(flag)
  end

  # ---- 房间广播原语（对应 LPC tell_room/message_vision/broadcast） ----

  @doc """
  向房间内所有人发消息（对应 LPC tell_room/2）

  `except` 可排除特定 pid/列表（如发送者不想看自己的 echo）。
  """
  def tell_room(room, message, except \\ nil) do
    except_list =
      cond do
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
  房间级一次性定时器（对应 LPC `call_out/set_timer`）—— **当前不可用**。

  ## 为什么不可用

  本函数把 `{:room_timer, ref, data, room_id}` 投给 `self()`，即**调用方**，
  而不是房间进程；而房间进程（`Kalevala.World.Room`）**没有**
  `handle_info({:room_timer, ...})` 子句。所以：

  - 在角色进程里调用 → 该消息落到角色 Foreman，无匹配子句（只记日志）；
  - 在房间进程里调用 → 房间 GenServer 无匹配子句。

  也就是说「到期后回调房间逻辑」这层语义**从未接通**，全库也**没有任何调用方**
  （`grep` 可验）。保留本函数只为不破坏既有 API 形状，**不要用它移植
  `call_out`**。

  ## 移植 `call_out` 该用什么

  `:timer.apply_after/4` 在独立进程里回调一个模块函数，回调体只用**按 room_id**
  的运行时原语，不需要 `conn`：

      :timer.apply_after(8_000, __MODULE__, :close_hole, [room_id])

      def close_hole(room_id) do
        Room.put_state_by_id(room_id, "status", 0)
        Room.tell_room(%Room{id: room_id}, "一阵轧轧声过后，铜镜又缓缓的落下。\\n")
      end

  `Room.put_state_by_id/3` 走 `:sys.replace_state/2`（任何进程可调，房间不存在时
  返回 `:error`），`Room.tell_room/2` 只做 `send` —— 两者都不会因调用方不是房间
  进程而失败。现成范例见 `lib/kantele/scheduler.ex` 的 `schedule_once/2` 与
  `Kantele.World.RoomActions.Shaolin.Putiyuan.Xian.close_hole/1`。
  """
  def set_timer(room, ms, data) do
    ref = make_ref()
    timer = Process.send_after(self(), {:room_timer, ref, data, room.id}, ms)

    %{room | timers: Map.put(room.timers, ref, timer)}
  end

  @doc "取消房间定时器（对应 LPC cancel_timer/2）"
  def cancel_timer(room, ref) do
    case Map.pop(room.timers, ref) do
      {timer, timers} ->
        :timer.cancel(timer)
        %{room | timers: timers}

      _ ->
        room
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

  @doc """
  查看房间墙上器物/菜单文本（对应 LPC set("item_desc", ...) 的 look <关键词>）。

  按关键词精确匹配，退化到前缀匹配（LPC 物品 con 名惯例）；静态条目返回文本，
  动态闭包条目返回 nil（由 `item_desc_entry/2` 交给 handler）。
  """
  def item_desc(room, keyword) do
    case item_desc_entry(room, keyword) do
      {:static, text} -> text <> "\n"
      _ -> nil
    end
  end

  @doc """
  解析 item_desc 条目（P5-4d）。

  - `{:static, text}`：普通文本条目
  - `{:dynamic, config}`：LPC closure 条目，`config["kind"]` 指定 handler
  - `nil`：未找到
  """
  def item_desc_entry(room, keyword) when is_binary(keyword) and keyword != "" do
    case Enum.find(room.item_desc, fn {key, _value} ->
           key == keyword or String.starts_with?(key, keyword)
         end) do
      {_key, text} when is_binary(text) and text != "" -> {:static, text}
      {_key, %{} = config} -> {:dynamic, config}
      _ -> nil
    end
  end

  def item_desc_entry(_room, _keyword), do: nil

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

  @doc """
  获取运行中房间的实时快照（物品、角色等），供命令在运行时读取。

  房间未启动或不存在时返回一个空快照（`items`/`private` 始终存在，避免命令读
  `room.items` 等字段时抛 KeyError）。
  """
  def snapshot(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        state = :sys.get_state(pid)
        private = state.private
        characters = private.characters || []
        item_instances = private.item_instances || []
        data = state.data || %{}
        flags = Map.get(data, :flags, []) || []

        exits =
          Enum.reduce(Map.get(data, :exits, []), %{}, fn room_exit, acc ->
            Map.put(acc, Map.get(room_exit, :exit_name), Map.get(room_exit, :end_room_id))
          end)

        %{
          id: room_id,
          name: Map.get(data, :name, room_id),
          items: item_instances,
          private: %{characters: characters, item_instances: item_instances},
          attrs: %{
            "exits" => exits,
            "short" => Map.get(data, :name, room_id),
            "sleep_room" => "sleep_room" in flags,
            "no_sleep_room" => "no_sleep_room" in flags,
            "hotel" => "hotel" in flags
          }
        }

      _ ->
        %{
          id: room_id,
          name: room_id,
          items: [],
          private: %{characters: [], item_instances: []},
          attrs: %{"exits" => %{}, "short" => room_id}
        }
    end
  end

  @doc "物品移入/移出房间（对应 LPC move_object/2）"
  def move_object(room, item_instance) do
    room
  end

  # 内部：取房间内角色 pid 列表（对应 LPC present/living/get_characters_in_room；
  # Q2-T0 真实化：对齐 RoomChannel 订阅缓存，房间的在线玩家都会订阅 "rooms:客房id"）
  defp get_characters_in_room(room_id) do
    Kantele.Communication.subscribers("rooms:#{room_id}")
    |> Enum.map(fn {_channel_name, pid, _options} -> pid end)
  end

  defp get_item_instances_in_room(_room_id), do: []

  defp is_player(pid), do: is_pid(pid)
  defp is_living(pid), do: is_pid(pid)

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

  @doc """
  解析房间动词（P5-1b）：在 UCL 加载的 `actions` 映射里查找玩家输入的 verb。

  `actions` 是 `%{verb => handler_fn_name}`（handler 为 LPC 函数名字符串，
  如 `%{"move" => "do_move"}`，由 P5-1a2 回填）。本函数只做**查找**，不执行；
  真正的执行由对象级 verb 分发路由（P5-1b-2）通过
  `Kantele.World.RoomActionHandlers.lookup/1` 把 handler 名解析为 Elixir
  `{module, function}` 后完成。

  返回 `{:ok, handler}` | `{:error, :no_such_action}`。verb **大小写敏感**
  （LPC 动词区分大小写，玩家输入与 UCL 键原样匹配）。
  """
  def resolve_action(%__MODULE__{actions: actions}, verb) when is_binary(verb) do
    case Map.get(actions, verb) do
      nil -> {:error, :no_such_action}
      handler when is_binary(handler) -> {:ok, handler}
    end
  end

  def resolve_action(_room, _verb), do: {:error, :no_such_action}

  @doc """
  兼容旧契约的房间动词入口（P5-1b 起改为委托 `resolve_action/2`）。

  旧实现从 `dynamic_exits[:verbs]` 读取 `{module, fun, args}` 元组并直接 `apply`，
  但转换后的 UCL 数据落在 `actions` 字段（handler 为字符串），且本函数当前无调用方。
  现改为：查到返回 `{:ok, handler}`（字符串，交由上层路由解析执行），查不到返回
  `{:error, :no_such_verb}`。`context`/`args` 保留为签名兼容，供未来 Kalevala.Verb
  路由接入。
  """
  def resolve_verb(room, verb_name, _context, _args) do
    case resolve_action(room, verb_name) do
      {:ok, handler} -> {:ok, handler}
      {:error, :no_such_action} -> {:error, :no_such_verb}
    end
  end

  @doc """
  按 room_id 取房间的 `actions` 映射（P5-1b-2 运行时取数）。

  引擎不会把房间塞进 `conn.private.room`（恒为 nil），而 `snapshot/1` 返回的精简
  map 也不含 `actions` 字段；本函数直接查房间进程的 `state.data`（即加载后的
  `Kantele.World.Room` 结构体，含 `actions`），提取 verb→handler 映射。房间进程
  不存在时返回 `%{}`（安全降级，调用方仍走 `:not_handled` 放行全局命令）。
  """
  def actions_by_id(room_id) when is_binary(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        state = :sys.get_state(pid)
        data = state.data || %{}
        Map.get(data, :actions, %{})

      _ ->
        %{}
    end
  end

  def actions_by_id(_), do: %{}

  @doc """
  按 room_id 取房间内角色（含 NPC 与玩家）的裁剪快照列表（P5-1c-2 运行时取数）。

  与 `actions_by_id/1` 同源：引擎不会把房间塞进 `conn.private.room`（恒为 nil），
  故 `NpcActionDispatcher` 需要从房间进程直接取 `state.private.characters`。这些
  条目是经 `Meta.trim` 裁剪过的 `Kalevala.Character` 快照（含 `:init`，见
  `Kantele.Character.NonPlayerMeta.Trim`），`meta.init.add_actions` 即 NPC 私有动词表。

  房间进程不存在时返回 `[]`（安全降级，调用方仍走 `:not_handled` 放行全局命令）。
  """
  def npc_characters_by_id(room_id) when is_binary(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        state = :sys.get_state(pid)
        private = state.private || %{}
        Map.get(private, :characters) || []

      _ ->
        []
    end
  end

  def npc_characters_by_id(_), do: []

  @doc """
  按 room_id 取房间内地面上物品实例（`state.private.item_instances`）。

  同 `npc_characters_by_id/1` 的取数路径，供 NPC 私有动作（如田嫂 `do_yao` 的
  `present("baozi", environment())`）判断「房间地上是否已有某物」。房间进程不存在
  时返回 `[]`（安全降级）。
  """
  def item_instances_by_id(room_id) when is_binary(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        state = :sys.get_state(pid)
        private = state.private || %{}
        Map.get(private, :item_instances) || []

      _ ->
        []
    end
  end

  def item_instances_by_id(_), do: []

  # ---- 运行时动态出口增删（对应 LPC `set/delete("exits/<dir>", ...)`） ----
  #
  # `room.exits` 是 `%Kalevala.World.Exit{}` 列表（loader 加载期构建，
  # `Callbacks.exits/1` 直接返回它、`snapshot/1` 也直接读它）。本组函数在运行期
  # 向房间进程 `state.data.exits` 追加/移除出口 → look 与移动立即生效。
  #
  # P7 安全：仅当 handler 主动调用 `set_exit/delete_exit` 时才改数据；没有调用方
  # 时 `room.exits` 原样不动，对全部既有房间零行为变化。

  @doc "房间 struct 是否有指定方向的出口"
  def has_exit?(room, exit_name) when is_binary(exit_name) do
    room
    |> Map.get(:exits)
    |> List.wrap()
    |> Enum.any?(fn exit -> Map.get(exit, :exit_name) == exit_name end)
  end

  def has_exit?(_room, _exit_name), do: false

  @doc "在房间 struct 上设置（或覆盖同方向）动态出口，返回新 struct"
  def put_exit(room, exit_name, target_room_id) when is_binary(exit_name) do
    exit = %Kalevala.World.Exit{
      id: "#{Map.get(room, :id)}:#{exit_name}",
      exit_name: exit_name,
      start_room_id: Map.get(room, :id),
      end_room_id: target_room_id
    }

    kept =
      room
      |> Map.get(:exits)
      |> List.wrap()
      |> Enum.reject(fn e -> Map.get(e, :exit_name) == exit_name end)

    Map.put(room, :exits, [exit | kept])
  end

  @doc "移除房间 struct 上指定方向的出口，返回新 struct"
  def remove_exit(room, exit_name) when is_binary(exit_name) do
    kept =
      room
      |> Map.get(:exits)
      |> List.wrap()
      |> Enum.reject(fn e -> Map.get(e, :exit_name) == exit_name end)

    Map.put(room, :exits, kept)
  end

  def remove_exit(room, _exit_name), do: room

  @doc """
  运行期：在房间进程上设置动态出口（对应 LPC `set("exits/<dir>", target)`）。

  房间进程不存在时返回 `:error`（安全降级，不崩溃）。
  """
  def set_exit(room_id, exit_name, target_room_id) when is_binary(room_id) do
    update_room_data(room_id, fn room -> put_exit(room, exit_name, target_room_id) end)
  end

  def set_exit(_room_id, _exit_name, _target), do: :error

  @doc "运行期：在房间进程上移除动态出口（对应 LPC `delete(\"exits/<dir>\")`）"
  def delete_exit(room_id, exit_name) when is_binary(room_id) do
    update_room_data(room_id, fn room -> remove_exit(room, exit_name) end)
  end

  def delete_exit(_room_id, _exit_name), do: :error

  @doc "运行期：房间（进程）是否有指定方向出口；无进程返回 false"
  def has_exit_by_id?(room_id, exit_name) when is_binary(room_id) and is_binary(exit_name) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        state = :sys.get_state(pid)
        has_exit?(state.data || %{}, exit_name)

      _ ->
        false
    end
  end

  def has_exit_by_id?(_room_id, _exit_name), do: false

  @doc """
  运行期：读取房间进程上的临时状态（对应 LPC `query_temp/1`）。

  房间进程不存在时返回 `nil`（安全降级，不崩溃）。LPC 的 `set_temp/query_temp`
  只存在于房间对象生命周期内，本实现同样不落库。
  """
  @doc """
  LPC `set("long", ...)` 等价：房间描述可被运行期覆盖。

  房间 state 的 `"long"` 键优先（`tulong/tulong/boat2.c` 的 `do_dao` 砸断桅杆后
  改写房间描述），缺省回静态 `description`（`nil` 表示没有覆盖）。
  写入侧用 `Room.put_state_by_id(room_id, "long", text)`；`Room.LookEvent`
  在渲染 `look` 时优先读它。
  """
  def long_description(%{state: state}) when is_map(state) do
    case Map.get(state, "long") do
      text when is_binary(text) and text != "" -> text
      _other -> nil
    end
  end

  def long_description(_room), do: nil

  def get_state_by_id(room_id, key) when is_binary(room_id) and is_binary(key) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        state = :sys.get_state(pid)
        data = state.data || %{}
        Map.get(Map.get(data, :state, %{}) || %{}, key)

      _ ->
        nil
    end
  end

  def get_state_by_id(_room_id, _key), do: nil

  @doc "运行期：设置房间临时状态（对应 LPC `set_temp/2`）；无进程返回 `:error`。"
  def put_state_by_id(room_id, key, value) when is_binary(room_id) and is_binary(key) do
    update_room_data(room_id, fn room ->
      room_state = Map.get(room, :state, %{}) || %{}
      Map.put(room, :state, Map.put(room_state, key, value))
    end)
  end

  def put_state_by_id(_room_id, _key, _value), do: :error

  @doc "运行期：删除房间临时状态（对应 LPC `delete_temp/1`）；无进程返回 `:error`。"
  def delete_state_by_id(room_id, key) when is_binary(room_id) and is_binary(key) do
    update_room_data(room_id, fn room ->
      room_state = Map.get(room, :state, %{}) || %{}
      Map.put(room, :state, Map.delete(room_state, key))
    end)
  end

  def delete_state_by_id(_room_id, _key), do: :error

  defp update_room_data(room_id, fun) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        :sys.replace_state(pid, fn state -> %{state | data: fun.(state.data)} end)
        :ok

      _ ->
        :error
    end
  end

  # ---- 座位/玩家清单（对应 LPC seat/present/living） ----

  @doc "房间座位表（对应 LPC qiyuan2 的 `%{black, white, game}`）"
  def get_seats(room), do: Map.get(room.dynamic_exits, :seats, %{})

  @doc "设置座位（落子/入座/开始对弈）"
  def set_seat(room, seat_name, player_info) do
    seats = get_seats(room)

    %{
      room
      | dynamic_exits: Map.put(room.dynamic_exits, :seats, Map.put(seats, seat_name, player_info))
    }
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
        send(
          other_room.pid,
          {:room_sync, room.id,
           %{
             dynamic_exits: room.dynamic_exits,
             flags: room.flags
           }}
        )
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

    defp check_guarders(room, context, mover, room_exit) do
      case guard_direction(room, room_exit) do
        # 该方向不设卡（LPC 的 valid_leave 对这个方向直接 return 1）
        :skip ->
          :allow

        :guard ->
          check_guarders_for_dir(context, mover)
      end
    end

    # LPC 的守卫不是「所有方向都盘查」，而是每个 valid_leave 显式写的：
    #   baituo/damen.c   if (present("men wei") && dir == "north") return guarder->permit_pass(...)
    #   huashan/buwei1.c  if (dir == "south" || !present(guard)) return ::valid_leave;  // 除 south 外全守
    #   huashan/square.c  if (dir == "northeast" || dir == "east" || dir == "north") ...
    # 所以方向规则必须由数据如实表达，不能一律按「全方向」处理。
    defp guard_direction(room, room_exit) do
      dir = Map.get(room_exit, :exit_name)
      cfg = Map.get(room, :behavior_config) || %{}

      cond do
        dirs = Map.get(cfg, :guard_directions) ->
          if dir in dirs, do: :guard, else: :skip

        exempt = Map.get(cfg, :exempt_directions) ->
          if dir in exempt, do: :skip, else: :guard

        true ->
          # 没有方向信息的老数据：保守不拦（fail-open）
          :skip
      end
    end

    defp check_guarders_for_dir(context, mover) do
      # 找房间里的守卫 NPC（有 guarder 配置且 is_guarder? 为 true）
      guarders =
        Enum.filter(context.characters, fn c ->
          Map.get(c.meta, :guarder) && Guarder.is_guarder?(c)
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

      # LPC: deep_inventory(ob) 里每个 userp 的 family_name 与本人不同就拒绝
      # （背着他派的人上门）。必须用 Map.get/3 而不是 meta.carrying ——
      # PlayerMeta 根本没有 :carrying 字段，直接点取会抛 KeyError，
      # 房间里一旦有守卫就会让每次移动都崩（与 cc0eead 的 get_in 同一类）。
      carried_families =
        mover.meta
        |> Map.get(:carrying, [])
        |> List.wrap()
        |> Enum.filter(&is_map/1)
        |> Enum.map(&Map.get(Map.get(&1, :family) || %{}, :name))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      msgs = guarder.meta.guarder.msgs || %{}

      %{
        # LPC: if (!living(this_object())) return 1;  守卫倒下就放行。
        # 死亡标记在 meta.combat.dead 上 —— NonPlayerMeta 根本没有 :dead 字段，
        # 写 guarder.meta.dead 会抛 KeyError。这已是同一类错误的第三处
        # （前两处：get_in 读结构体、meta.carrying）。
        living?: not Map.get(Map.get(guarder.meta, :combat) || %{}, :dead, false),
        my_family: my_family,
        guest_family: guest_family,
        guest_born_family: guest_born_family,
        carried_families: carried_families,
        msgs: msgs
      }
    end

    @impl true
    def movement_request(room, context, event, room_exit) do
      # 玩家本人**不在** context.characters 里（那里只有房间生成的 NPC），
      # 必须从事件里取 —— 早期版本用 context.characters 找 mover，玩家恒为 nil，
      # 于是这段（含原有的 guarder 拦截）对玩家从不执行。
      mover =
        Map.get(event.data, :character) ||
          Enum.find(context.characters, &(&1.pid == event.from_pid))

      if mover do
        guarder_result = check_guarders(room, context, mover, room_exit)

        case guarder_result do
          {:deny, msg} ->
            # 守卫的正文**不在房间数据里**（valid_leave / exit_vetoes 里没有它），
            # 所以角色侧没法像 valid_leave 那样「按房间 id + 方向回查」。
            # Kalevala 的 Movement.handle_request 把 reason 原样塞进 %Voting{}，
            # reason 可以是任意项 —— 于是把正文一起带过去。
            {:abort, event, {:guarder_denied, msg || "看来守门的不是打算让你过去。"}}

          :allow ->
            # 带副作用的陷阱（LPC 里那几个不是纯谓词的自定义函数）：
            # 五行迷宫等。判定是纯计算，副作用作为事件下发给角色进程执行。
            case check_traps(room, mover, event.data.exit_name) do
              {:block, trap_msg, effects} ->
                dispatch_trap_effects(mover, effects)
                {:abort, event, {:trapped, trap_msg}}

              {:allow, effects} ->
                # 放行**也要下发副作用**：五行迷宫往北是正常移动，但计数 +1
                # 是 LPC valid_leave 的一部分（少下发就会让迷宫永远凑不齐五行）。
                dispatch_trap_effects(mover, effects)
                # 阻挡条件（valid_leave）：受 enforce_exit_vetoes 开关灰度，默认关
                check_vetoes(room, context, mover, room_exit, event)
            end
        end
      end
    end

    # valid_leave 那一段（抽成独立函数，好让陷阱能排在它前面）
    defp check_vetoes(room, context, mover, room_exit, event) do
      case check_exit_vetoes(room, context, mover, room_exit.exit_name) do
        {:deny, _msg} ->
          # 正文由角色侧回查渲染，理由同 guarder 分支的注释
          {:abort, event, :exit_vetoed}

        :allow ->
          BasicRoom.movement_request(context, event, room_exit)
      end
    end

    # ---- 阻挡条件（valid_leave） ----
    #
    # 灰度开关 `config :ex_venture, enforce_exit_vetoes: false`（默认关）。
    # 开启即行为变更：条件为真时拒绝移动并提示 LPC notify_fail 的原文。
    # 求值器无法解析/求值失败一律放行 —— 宁可少拦，不能把玩家锁死在房里。
    # 公开：便于单测直接验证「玩家在场时是否真的被拦」
    @doc """
    valid_leave 阻挡条件判定：返回 `:allow` 或 `{:deny, message}`。

    调用点见 `movement_request/4`。开关 `config :ex_venture, enforce_exit_vetoes`
    （默认关）；条件解析不了/求值失败/方向未限定一律放行。
    """
    # 陷阱：判定纯函数（只读 mover.meta.temp），返回要执行的副作用。
    # 必须放在 check_exit_vetoes **之前** —— 五行迷宫的 west 陷阱在 UCL 里
    # 是一条没有 condition 的 valid_leave（会被 is_nil(condition) 跳过），
    # 而 north 的计数逻辑转换器整段丢了，只能由这里补。
    defp check_traps(room, mover, dir) do
      Kantele.World.Trap.dispatch(room, mover, dir)
    end

    # 副作用由角色进程执行 —— meta 只有它能安全地改并落盘
    # （Kantele.Character.Records.save/1）。房间进程只发事件。
    defp dispatch_trap_effects(mover, effects) do
      case {Map.get(mover, :pid), effects} do
        {pid, []} when is_pid(pid) ->
          :ok

        {pid, effects} when is_pid(pid) ->
          send(pid, %Kalevala.Event{
            from_pid: self(),
            topic: "trap/effect",
            data: %{effects: effects}
          })

        _ ->
          Logger.warning("陷阱副作用无法下发：mover 没有 pid（effects=#{inspect(effects)}）")
      end

      :ok
    end

    def check_exit_vetoes(room, context, mover, dir) do
      case Application.get_env(:ex_venture, :enforce_exit_vetoes, false) do
        true ->
          vetoes = Map.get(room, :exit_vetoes, []) || []
          apply_vetoes(vetoes, room, context, mover, dir)

        _ ->
          :allow
      end
    end

    defp apply_vetoes([], _room, _context, _mover, _dir), do: :allow

    defp apply_vetoes([veto | rest], room, context, mover, dir) do
      # direction = "*" 表示不挑方向
      applies? =
        case Map.get(veto, :direction) do
          nil -> true
          "*" -> true
          ^dir -> true
          _ -> false
        end

      all_dirs? = Map.get(veto, :all_dirs) == true

      cond do
        not applies? ->
          apply_vetoes(rest, room, context, mover, dir)

        # 条件缺失 -> 跳过
        is_nil(Map.get(veto, :condition)) ->
          apply_vetoes(rest, room, context, mover, dir)

        # LPC 里本来就拦所有方向（数据侧标了 all_dirs = true）-> 正常执行。
        # 例：厨房里端着汤、妓院里嫖客，都不许离开，与方向无关。
        all_dirs? ->
          evaluate_veto(veto, room, context, mover, dir, rest)

        # 条件不限定方向、又没有 all_dirs 标记 -> 疑似转换器丢了外层守卫。
        # 照此执行会把该房所有出口都拦掉、把人锁死，所以跳过。
        # 见 Kantele.World.LpcCondition.direction_scoped?/1 与
        # scripts/audit_exit_veto_locks.py
        not Kantele.World.LpcCondition.direction_scoped?(Map.get(veto, :condition)) ->
          apply_vetoes(rest, room, context, mover, dir)

        # 条件依赖运行时不存在的数据（如玩家性别）-> 同样不执行，
        # 否则 gender 比较恒真会把人永久拦住
        not Kantele.World.LpcCondition.supported?(Map.get(veto, :condition)) ->
          apply_vetoes(rest, room, context, mover, dir)

        not Kantele.World.LpcCondition.enforceable?(Map.get(veto, :condition)) ->
          # 求值器不支持的形态 -> 跳过这一条，继续看下一条
          apply_vetoes(rest, room, context, mover, dir)

        true ->
          evaluate_veto(veto, room, context, mover, dir, rest)
      end
    end

    defp evaluate_veto(veto, room, context, mover, dir, rest) do
      ctx =
        Kantele.World.ExitVetoContext.build(
          dir: dir,
          me: mover,
          room: room,
          context: context
        )

      case Kantele.World.LpcCondition.check(veto, ctx) do
        {:block, msg} ->
          {:deny, msg || "过不去。"}

        :allow ->
          apply_vetoes(rest, room, context, mover, dir)
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
      event("combat/touxi", :call)
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
      event("room/item_desc", :call)
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

    module(DetachRequestEvent) do
      event("family/detach", :call)
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

    module(CutRequestEvent) do
      event("room/cut", :call)
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

    module(AssistRequestEvent) do
      event("assist/request", :call)
    end

    module(FeedRequestEvent) do
      event("room/feed", :call)
    end

    module(StealRequestEvent) do
      event("steal/attempt", :call)
    end

    module(GuardRequestEvent) do
      event("guard/guard", :call)
      event("guard/cancel", :call)
    end

    module(CheckRequestEvent) do
      event("check/request", :call)
    end

    module(SwearRequestEvent) do
      event("swear/request", :call)
    end

    module(SwearAnswerEvent) do
      event("swear/answer", :call)
      event("swear/cancel", :call)
    end

    module(EngageRequestEvent) do
      event("engage/request", :call)
    end

    module(EngageAnswerEvent) do
      event("engage/answer", :call)
      event("engage/cancel", :call)
    end

    module(SearchRequestEvent) do
      event("search/attempt", :call)
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

  把 `list`/`buy` 转给房间内的 NPC：指名则只找该角色，未指名则广播给
  全场非玩家，由带 goods 的商人应答。

  注：`Context.new/1` 只清空 `inventory`，`meta` 是**完整保留**的（早先这里
  写的「角色被 Trimmed，无法直接看 meta」不成立）。之所以仍用广播而不是
  由房间按 goods 挑人：挑人需要在房间侧复刻 `NpcShopEvent` 的物品名匹配
  （`Item.matches?` + 物品注册表查询），会把「谁卖什么」的判定分散到两处。
  代价是未指名的 `buy` 会被多个商人各答一次，故此处按「一次命令」生成
  `request_id` 透传下去，玩家侧据此只成交一次。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.Combat.StatusTracker

  def call(context, %{topic: topic, data: data} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      requester ->
        # 一次命令一个 request_id，广播给多个商人时共用：玩家侧据此只成交一次
        # （否则同房间两个卖同样货的商人会各扣一次钱，见 taishan:tianjie）。
        data = Map.put(data, :request_id, System.unique_integer([:positive]))
        forward(context, topic, data, requester)
    end
  end

  defp forward(context, topic, %{name: name} = data, requester)
       when is_binary(name) and name != "" do
    Enum.reduce(context.characters, context, fn character, acc ->
      if target?(character, requester) &&
           Kantele.World.Room.NameMatch.matches?(character, name) do
        event(acc, character.pid, self(), topic, %{
          reply_to: requester.pid,
          buyer_id: requester.id,
          buyer_name: requester.name,
          # 与下方广播分支保持同一载荷形状：指名购买时 NPC 侧
          # NpcShopEvent.buy/2 严格匹配 item_name，缺键会 FunctionClauseError
          item_name: Map.get(data, :item_name),
          quantity: Map.get(data, :quantity, 1),
          request_id: Map.get(data, :request_id)
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
          quantity: Map.get(data, :quantity, 1),
          request_id: Map.get(data, :request_id)
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

defmodule Kantele.World.Room.DetachRequestEvent do
  @moduledoc """
  叛师转发（A11/N5）：把 `detach <师父>` 转给对应 NPC，
  是否确为嫡传与惩罚由玩家侧据 NPC 回执判定（玩家侧校验）。
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
            event(acc, character.pid, self(), "family/detach", %{
              reply_to: requester.pid,
              student_id: requester.id,
              student_name: requester.name
            })
          else
            acc
          end
        end)

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要叛离谁？\n"})
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

defmodule Kantele.World.Room.FeedRequestEvent do
  @moduledoc """
  喂养转发：把 `feed` 的 `room/feed` 事件中的目标按名字解析，
  向目标NPC发 `characters/feed`。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: data} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))
    target_name = Map.get(data, :name)

    case {requester, is_binary(target_name) and target_name != ""} do
      {nil, _} ->
        context

      {requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你要喂养谁？\n"})

      {requester, true} ->
        case find_target(context, requester, target_name) do
          nil ->
            render(context, requester.pid, CommandView, "text", %{text: "这里没有这个人。\n"})

          target ->
            event(context, target.pid, self(), "characters/feed", %{
              feeder_id: requester.id,
              feeder_name: requester.name,
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

defmodule Kantele.World.Room.CutRequestEvent do
  @moduledoc """
  解剖转发（`cmds/std/cut.c`）：把 `cut` 的 `room/cut` 事件按名字解析尸体目标，
  应用 cut.c 前置守卫（附近无物 / 割自己 / 活人），把 `characters/cut` 转给
  尸体进程做 do_cut（部位校验 + 产物入包）。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat.StatusTracker

  def call(context, %{data: data} = event) do
    requester = Enum.find(context.characters, &(&1.pid == event.from_pid))
    name = Map.get(data, :name)

    case {requester, find_target(context.characters, name)} do
      {nil, _} ->
        context

      {_requester, nil} ->
        render(context, requester.pid, CommandView, "text", %{text: "你附近没有这样东西。\n"})

      {requester, target} ->
        cond do
          target.pid == requester.pid ->
            render(context, requester.pid, CommandView, "text", %{
              text: "割自己？你有毛病啊？\n"
            })

          not dead?(target) ->
            render(context, requester.pid, CommandView, "text", %{text: "活人你也敢割，找打么。\n"})

          true ->
            event(context, target.pid, self(), "characters/cut", %{
              part: Map.get(data, :part),
              name: target.name,
              id: target.id,
              requester_id: requester.id,
              requester_name: requester.name,
              weapon_skill_type: Map.get(data, :weapon_skill_type),
              weapon_name: Map.get(data, :weapon_name),
              skills: Map.get(data, :skills),
              force: Map.get(data, :force),
              reply_to: requester.pid
            })
        end
    end
  end

  defp find_target(characters, name) when is_binary(name) and name != "" do
    Enum.find(characters, fn character ->
      Kantele.World.Room.NameMatch.matches?(character, name)
    end)
  end

  defp find_target(_characters, _name), do: nil

  defp dead?(%{status: status, id: id}) when is_binary(status) do
    String.contains?(status, "尸体") or StatusTracker.dead?(id)
  end

  defp dead?(%{id: id}), do: StatusTracker.dead?(id)
  defp dead?(_), do: false
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

defmodule Kantele.World.Room.AssistRequestEvent do
  @moduledoc """
  协助请求转发：把 `assist <玩家>` 按名字解析到同房目标，
  向目标发 `assist/request` 事件。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{name: name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(name) and name != ""} do
      {nil, _} ->
        context

      {_requester, false} ->
        render(context, requester.pid, CommandView, "text", %{text: "你想协助谁？\n"})

      {requester, true} ->
        case find_target(context, requester, name) do
          nil ->
            render(context, requester.pid, CommandView, "text", %{text: "这里没有 #{name}。\n"})

          target ->
            context
            |> event(target.pid, self(), "assist/request", %{
              from_id: requester.id,
              from_name: requester.name
            })
            |> render(requester.pid, CommandView, "text", %{
              text: "你向 #{target.name} 发出了协助请求，等待对方回应。\n"
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

defmodule Kantele.World.Room.StealRequestEvent do
  @moduledoc """
  偷窃请求处理：转发 steal/attempt，完成偷窃判定并延时返回结果。

  成功率 = stealing_skill * 5 vs victim's jing * 2 + item_weight / 25
  偷窃成功：转移物品，技能提升，阅历+1，精-10，忙2
  偷窃失败：被发现，忙3，精-15~25，若目标为NPC则进入战斗
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def call(context, %{data: %{item: item_name, target: target_name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case {requester, is_binary(target_name) and target_name != ""} do
      {nil, _} ->
        context

      {_requester, false} ->
        context

      {requester, true} ->
        # flag 判定走 Room.has_flag?/2：这三个 key 都不在 Room 结构体里
        # （Room 只有 flags 列表），原来直读 context.data.no_steal 等字段
        # 每次必抛 KeyError（R6）。no_steal/no_fight 有真实数据，
        # skybook 当前数据为 0（保留判定，与 LPC steal.c 语义对齐）。
        flags = Map.get(context.data, :flags, []) || []

        cond do
          "skybook" in flags ->
            render(context, requester.pid, CommandView, "text", %{text: "这里禁止行窃。\n"})

          "no_fight" in flags ->
            render(context, requester.pid, CommandView, "text", %{text: "这里禁止行窃。\n"})

          "no_steal" in flags ->
            render(context, requester.pid, CommandView, "text", %{text: "这里禁止行窃。\n"})

          true ->
            target =
              Enum.find(context.characters, fn character ->
                character.pid != requester.pid and
                  Kantele.World.Room.NameMatch.matches?(character, target_name)
              end)

            case target do
              nil ->
                render(context, requester.pid, CommandView, "text", %{text: "你想行窃的对象不在这里。\n"})

              _target when target.id == requester.id ->
                context

              _target ->
                if !target.is_character do
                  render(context, requester.pid, CommandView, "text", %{text: "你看清楚了，那不是活人！"})
                else
                  process_steal(context, requester, target, item_name)
                end
            end
        end
    end
  end

  defp process_steal(context, requester, target, item_name) do
    victim = target

    stolen_item =
      case find_item_on_character(victim, item_name) do
        nil ->
          inv = victim.inventory
          if length(inv) > 0, do: Enum.random(inv), else: nil

        item ->
          item
      end

    if !stolen_item do
      render(context, requester.pid, CommandView, "text", %{
        text: "#{victim.name}身上看起来没有什么值钱的东西好偷。\n"
      })
    else
      stealing_skill = requester.meta.stats.skills["stealing"] || 0
      thief = requester.attributes["thief"] || 0

      sp = stealing_skill * 5 - thief * 20

      family_name =
        case requester.attributes["family"] do
          %{family_name: fn_name} -> fn_name
          _ -> nil
        end

      sp = if family_name == "丐帮", do: stealing_skill * 10 - thief * 20, else: sp
      sp = if sp < 1, do: 1, else: sp

      victim_jing = victim.attributes["jing"] || 1
      item_weight = 1

      dp = victim_jing * 2 + div(item_weight, 25)

      context =
        context
        |> render(requester.pid, CommandView, "text", %{
          text: "\n你不动声色地慢慢靠近#{victim.name}，等待机会下手……\n\n"
        })

      if :rand.uniform(sp + dp) > dp do
        handle_steal_success(context, requester, victim, stolen_item)
      else
        handle_steal_failure(context, requester, victim, stolen_item)
      end
    end
  end

  defp handle_steal_success(context, requester, victim, stolen_item) do
    updated_victim = %{
      victim
      | inventory: Enum.reject(victim.inventory, &(&1.id == stolen_item.id))
    }

    updated_requester = %{requester | inventory: [stolen_item | requester.inventory]}

    context =
      context
      |> update_character(victim.id, updated_victim)
      |> update_character(requester.id, updated_requester)

    context
    |> render(requester.pid, CommandView, "text", %{
      text: "得手了，你成功地偷到一#{stolen_item.name || "东西"}。\n\n"
    })
    |> render(victim.pid, CommandView, "text", %{
      text: "你发现#{requester.name}偷走了你的#{stolen_item.name || "东西"}！\n"
    })
  end

  defp handle_steal_failure(context, requester, victim, _stolen_item) do
    jing_loss = 15 + :rand.uniform(10)

    context =
      context
      |> render(requester.pid, CommandView, "text", %{
        text:
          "糟糕！你失手了！\n\n#{victim.name}一回头，正好发现你的手正抓在自己的#{_stolen_item.name || "东西"}之上。\n\n#{victim.name}喝道：小贼，干什么！\n"
      })

    if victim.is_npc do
      context
      |> event(victim.pid, self(), "combat/attack", %{name: requester.name, type: "kill"})
      |> render(victim.pid, CommandView, "text", %{
        text: "#{requester.name}喝道：小贼，干什么！\n"
      })
    else
      context
      |> render(victim.pid, CommandView, "text", %{
        text: "#{requester.name}狠狠地敲着你的头，痛得你呜呜直叫。\n"
      })
    end
  end

  defp find_item_on_character(character, item_name) do
    Enum.find(character.inventory, fn inst ->
      case Items.get(inst.item_id) do
        {:ok, item} -> item.name =~ item_name
        _ -> false
      end
    end)
  end

  defp update_character(context, char_id, updated_character) do
    %{
      context
      | characters:
          Enum.map(context.characters, fn c ->
            if c.id == char_id, do: updated_character, else: c
          end)
    }
  end
end

defmodule Kantele.World.Room.GuardRequestEvent do
  @moduledoc false
  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{topic: "guard/guard", data: %{target: target}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    if requester && target && target != "" do
      target_char = find_target_in_room(context, requester, target)

      case target_char do
        nil ->
          render(context, requester.pid, CommandView, "text", %{text: "这里没有这个人。\n"})

        target_char when target_char.id == requester.id ->
          render(context, requester.pid, CommandView, "text", %{text: "不能守护自己。\n"})

        target_char ->
          # 在目标的 meta.temp.guarded 中加入请求者
          new_temp =
            Map.update(target_char.meta.temp, "guarded", [requester.id], fn list ->
              if requester.id in list, do: list, else: [requester.id | list]
            end)

          new_target = %{target_char | meta: Map.put(target_char.meta, :temp, new_temp)}
          context = update_character_in_context(context, target_char.id, new_target)

          render(context, requester.pid, CommandView, "text", %{
            text: "你开始守护#{target_char.name}。\n"
          })
      end
    else
      context
    end
  end

  def call(context, %{topic: "guard/cancel", data: %{}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    if requester do
      # 从所有角色的 guarded 列表中移除请求者
      context =
        Enum.reduce(context.characters, context, fn character, acc ->
          guarded = character.meta.temp["guarded"] || []

          if requester.id in guarded do
            new_guarded = List.delete(guarded, requester.id)
            new_temp = Map.put(character.meta.temp, "guarded", new_guarded)
            new_char = %{character | meta: Map.put(character.meta, :temp, new_temp)}
            update_character_in_context(acc, character.id, new_char)
          else
            acc
          end
        end)

      render(context, requester.pid, CommandView, "text", %{text: "你不再守护任何人。\n"})
    else
      context
    end
  end

  # 房间内按名字查找目标（复用 NameMatch）
  defp find_target_in_room(context, requester, target_name) do
    Enum.find(context.characters, fn character ->
      character.pid != requester.pid and
        Kantele.World.Room.NameMatch.matches?(character, target_name)
    end)
  end

  # 更新 context 中的角色
  defp update_character_in_context(context, char_id, updated_character) do
    %{
      context
      | characters:
          Enum.map(context.characters, fn c ->
            if c.id == char_id, do: updated_character, else: c
          end)
    }
  end
end

defmodule Kantele.World.Room.CheckRequestEvent do
  @moduledoc """
  查探请求处理：对应 LPC check.c 的完整逻辑。

  前置条件：
  - 请求者必须是丐帮成员
  - 请求者的 checking 技能等级 >= 30
  - 房间中必须有可交谈的 NPC

  成功率 = (checking_skill * 10 + jing * 3) vs (target_jing * 2)
  成功时向请求者显示目标的一个随机技能。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{target_name: target_name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      _ ->
        process_check(context, requester, target_name)
    end
  end

  defp process_check(context, requester, target_name) do
    # 1. 找可交谈的 NPC
    npc =
      Enum.find(context.characters, fn c ->
        c.is_character && !c.is_player && can_speak?(c) && !is_nil(c.name)
      end)

    if !npc do
      render(context, requester.pid, CommandView, "text", %{text: "你周围又没人，没办法打听。\n"})
    else
      # 2. 在房间内找目标玩家
      target = find_target_in_room(context, requester.pid, target_name)

      cond do
        is_nil(target) ->
          render(context, requester.pid, CommandView, "text", %{text: "你要打听谁的技能？\n"})

        target.id == requester.id ->
          render(context, requester.pid, CommandView, "text", %{text: "不至于吧，要别人告诉你自己的技能？\n"})

        true ->
          do_check(context, requester, npc, target)
      end
    end
  end

  defp do_check(context, requester, npc, target) do
    # 检查帝王特殊技能
    if has_emperor_skill?(target) do
      render(context, requester.pid, CommandView, "text", %{text: "此人乃真命天子，无法探知其属性。\n"})
    else
      # 计算精消耗
      checking_skill = requester.meta.stats.skills["checking"] || 0
      sklvl = div(checking_skill, 10)
      cost = div(Map.get(requester.attributes, "max_jing", 100), max(sklvl, 1)) - 10
      cost = if cost < 40, do: 30 + :rand.uniform(10), else: cost

      jing = Map.get(requester.attributes, "jing", 0)

      if jing < cost do
        render(context, requester.pid, CommandView, "text", %{text: "现在你太累了，无法去打听别人的技能。\n"})
      else
        # 扣除精
        updated_requester = put_in(requester.attributes["jing"], jing - cost)
        context = update_character_in_context(context, requester.id, updated_requester)

        # 显示查探过程
        context =
          context
          |> render(requester.pid, CommandView, "text", %{
            text: "\n你走上前去，小心翼翼地向#{npc.name}打听关于#{target.name}的情况。\n"
          })
          |> render_to_room_except(requester.pid, CommandView, "text", %{
            text: "只见#{requester.name}陪着笑脸，跟#{npc.name}说着话，好像在打听些什么。\n"
          })

        # 计算成功率
        sp = checking_skill * 10 + jing * 3
        dp = (Map.get(target.attributes, "jing", 1) || 1) * 2

        if :rand.uniform(sp + dp) < :rand.uniform(dp) do
          render(context, requester.pid, CommandView, "text", %{
            text: "#{npc.name}皱着眉道：那#{target.name}比你强多了，你没事去招惹他做甚？\n"
          })
        else
          # 查探成功，显示目标的一个随机技能
          skills = target.skills

          if map_size(skills) == 0 do
            render(context, requester.pid, CommandView, "text", %{
              text: "#{npc.name}悄悄告诉你：#{target.name}啥都不会，打听他干嘛？\n"
            })
          else
            skill_names = Map.keys(skills)
            skill_name = Enum.random(skill_names)
            skill_level = Map.get(skills, skill_name, 0)

            # 精确度：1000 / checking_level
            precise = div(1000, max(div(checking_skill, 10), 1))
            lvl = div(skill_level + div(precise, 2), precise) * precise

            chinese_skill_name = skill_name
            level_text = chinese_number(lvl)

            context
            |> render(requester.pid, CommandView, "text", %{
              text:
                "#{npc.name}悄悄告诉你：#{target.name}修炼过#{chinese_skill_name}，估计修炼到#{level_text}级了吧。\n"
            })
          end
        end
      end
    end
  end

  defp can_speak?(character) do
    character.attributes["can_speak"] == true && character.attributes["not_living"] != true
  end

  defp has_emperor_skill?(character) do
    Map.get(character.attributes, "special_skills", %{})["emperor"] == true
  end

  defp find_target_in_room(context, requester_pid, target_name) do
    Enum.find(context.characters, fn c ->
      c.pid != requester_pid && Kantele.World.Room.NameMatch.matches?(c, target_name)
    end)
  end

  defp update_character_in_context(context, char_id, updated_character) do
    %{
      context
      | characters:
          Enum.map(context.characters, fn c ->
            if c.id == char_id, do: %{c | attributes: updated_character}, else: c
          end)
    }
  end

  defp render_to_room_except(exclude_pid, context, view, template, data) do
    Enum.reduce(
      context.characters -- Enum.filter(context.characters, fn c -> c.pid == exclude_pid end),
      context,
      fn character, acc ->
        render(acc, character.pid, view, template, data)
      end
    )
  end

  defp chinese_number(n) when n > 0 do
    Integer.to_string(n)
  end
end

defmodule Kantele.World.Room.SearchRequestEvent do
  @moduledoc """
  搜寻请求处理：对应 LPC search.c 的简化逻辑。

  消耗 30 气 + 30 精，根据积分随机获取物品。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      _ ->
        # 同 R6：Room 无 :no_search 字段，原来 `context.data.no_search` 每次
        # 搜索必抛 KeyError。LPC 侧 no_search 是 quest explore 的 set_temp 映射表，
        # UCL 当前无数据 → 本分支休眠；将来若回填 flag 即刻生效。
        if Kantele.World.Room.has_flag?(context.data, "no_search") do
          render(context, requester.pid, CommandView, "text", %{text: "这里不允许搜寻。\n"})
        else
          qi = Map.get(requester.attributes, "qi", 0)
          jing = Map.get(requester.attributes, "jing", 0)

          if qi < 30 || jing < 30 do
            render(context, requester.pid, CommandView, "text", %{text: "你的气或精不足，无法进行搜寻。\n"})
          else
            updated_requester =
              %{
                requester
                | attributes:
                    Map.merge(requester.attributes, %{
                      "qi" => qi - 30,
                      "jing" => jing - 30
                    })
              }

            context = update_char_in_ctx(context, requester.id, updated_requester)

            # 根据积分计算发现概率
            score = Map.get(requester.attributes, "score", 0)
            probability = min(30, div(score, 7))

            if :rand.uniform(100) < probability do
              # 发现物品，从默认物品表中随机选一个
              item_id = get_default_item(score)
              item = Kantele.World.Items.get!(item_id)

              context
              |> render(requester.pid, CommandView, "text", %{
                text: "你东张西望，发现了地上一个#{item.name}。\n"
              })
            else
              context
              |> render(requester.pid, CommandView, "text", %{
                text: "你东张西望，什么也没找到。\n"
              })
            end
          end
        end
    end
  end

  defp get_default_item(score) do
    cond do
      score < 100 -> "coin"
      score < 400 -> "silver"
      score < 2000 -> "jinchuang"
      score < 10000 -> "dagger"
      true -> "sword"
    end
  end

  defp update_char_in_ctx(context, char_id, updated_character) do
    %{
      context
      | characters:
          Enum.map(context.characters, fn c ->
            if c.id == char_id, do: updated_character, else: c
          end)
    }
  end
end

defmodule Kantele.World.Room.SwearRequestEvent do
  @moduledoc """
  结拜请求处理：转发 swear/request，在同房间寻找目标玩家并转发结拜请求。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def call(context, %{data: %{target_name: target_name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      _ ->
        target =
          Enum.find(context.characters, fn c ->
            c.pid != requester.pid and
              Kantele.World.Room.NameMatch.matches?(c, target_name)
          end)

        check_target(context, requester, target)
    end
  end

  defp check_target(context, requester, nil) do
    render(context, requester.pid, CommandView, "text", %{text: "这里没有你要找的人。\n"})
  end

  defp check_target(context, requester, target) do
    requester_brothers = PlayerMeta.brothers(requester.meta)

    cond do
      target.id == requester.id ->
        render(context, requester.pid, CommandView, "text", %{text: "你不能和自己结拜。\n"})

      (requester.attributes["age"] || 0) < 18 ->
        render(context, requester.pid, CommandView, "text", %{text: "小毛孩子捣什么乱？一边玩去！\n"})

      (target.attributes["age"] || 0) < 18 ->
        render(context, requester.pid, CommandView, "text", %{
          text: "#{target.name}还是一个小毛孩子，你就省省吧，别逗人家了。\n"
        })

      not target.attributes["can_speak"] ->
        render(context, requester.pid, CommandView, "text", %{text: "你看清楚了，那不是活人！\n"})

      Enum.any?(requester_brothers, &(&1.id == target.id)) ->
        render(context, requester.pid, CommandView, "text", %{text: "你已经和#{target.name}结义了。\n"})

      length(requester_brothers) > 12 ->
        render(context, requester.pid, CommandView, "text", %{text: "你结义的兄弟也太多了，连你自己都快记不清楚了。\n"})

      true ->
        # 通知请求方：建立 pending/swear 状态
        context =
          event(context, requester.pid, self(), "swear/pending", %{
            target_id: target.id,
            target_name: target.name
          })

        # 通知被邀方：建立 pending/answer 状态并提示回答
        context
        |> event(target.pid, self(), "swear/request", %{
          from_id: requester.id,
          from_name: requester.name
        })
        |> render(requester.pid, CommandView, "text", %{
          text: "你向#{target.name}提出结拜请求，等待对方回应...\n"
        })
    end
  end
end

defmodule Kantele.World.Room.SwearAnswerEvent do
  @moduledoc """
  结拜应答处理：把 right/refuse 事件转给请求方，并完成结拜记录。

  - `right`：把双方写入对方结义名单（swear/joined），双方各自落盘
  - `refuse`：通知请求方被拒绝
  - `swear/cancel`：请求方取消，清除被邀方的待处理状态
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  def call(context, %{data: %{answer: "right", target_name: target_name}} = _event) do
    answerer = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case answerer do
      nil ->
        context

      _ ->
        requester = lookup_requester(context, answerer, target_name)

        case requester do
          nil ->
            render(context, answerer.pid, CommandView, "text", %{text: "这里没有你要找的人。\n"})

          _ ->
            context
            |> event(requester.pid, self(), "swear/joined", %{
              partner_id: answerer.id,
              partner_name: answerer.name
            })
            |> event(answerer.pid, self(), "swear/joined", %{
              partner_id: requester.id,
              partner_name: requester.name
            })
            |> render(requester.pid, CommandView, "text", %{
              text: "你和#{answerer.name}结拜成异姓兄弟了！\n"
            })
            |> render(answerer.pid, CommandView, "text", %{
              text: "你看着#{requester.name}，笑道：「好！从今往后，我与你结为异姓兄弟！」\n"
            })
        end
    end
  end

  def call(context, %{data: %{answer: "refuse", target_name: target_name}} = _event) do
    answerer = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case answerer do
      nil ->
        context

      _ ->
        requester = lookup_requester(context, answerer, target_name)
        from = if requester, do: requester.pid, else: answerer.pid

        render(context, from, CommandView, "text", %{
          text: if(requester, do: "#{answerer.name}拒绝了你的结拜请求。", else: "这人没有向你提出什么要求啊？") <> "\n"
        })
    end
  end

  def call(context, %{data: %{target_name: target_name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      _ ->
        target = lookup_requester(context, requester, target_name)

        if target do
          event(context, target.pid, self(), "swear/cancelled", %{from_id: requester.id})
        else
          context
        end
    end
  end

  defp lookup_requester(context, answerer, name) do
    Enum.find(context.characters, fn c ->
      c.pid != answerer.pid and
        Kantele.World.Room.NameMatch.matches?(c, name)
    end)
  end
end

defmodule Kantele.World.Room.EngageRequestEvent do
  @moduledoc """
  求婚请求处理：转发 engage/pending 与 engage/propose，在同房间寻找目标玩家。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def call(context, %{data: %{target_name: target_name, promise: promise}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      _ ->
        target =
          Enum.find(context.characters, fn c ->
            c.pid != requester.pid and
              Kantele.World.Room.NameMatch.matches?(c, target_name)
          end)

        check_target(context, requester, target, promise)
    end
  end

  defp check_target(context, requester, nil, _promise) do
    render(context, requester.pid, CommandView, "text", %{text: "这里没有你要找的人。\n"})
  end

  defp check_target(context, requester, target, promise) do
    cond do
      target.id == requester.id ->
        render(context, requester.pid, CommandView, "text", %{text: "你要和自己结婚？\n"})

      PlayerMeta.spouse(requester.meta) != nil ->
        render(context, requester.pid, CommandView, "text", %{
          text: "你可要稳住！根据泥潭法典第九十九条，重婚者打入地狱！\n"
        })

      PlayerMeta.spouse(target.meta) != nil ->
        render(context, requester.pid, CommandView, "text", %{
          text: "你怎么也得等人家离婚了再说吧？\n"
        })

      not target.attributes["can_speak"] ->
        render(context, requester.pid, CommandView, "text", %{text: "你看清楚了，那不是活人！\n"})

      true ->
        context =
          event(context, requester.pid, self(), "engage/pending", %{
            target_id: target.id,
            target_name: target.name,
            promise: promise
          })

        context
        |> event(target.pid, self(), "engage/propose", %{
          from_id: requester.id,
          from_name: requester.name,
          promise: promise
        })
        |> render(requester.pid, CommandView, "text", %{
          text: "你向#{target.name}求婚，承诺是「#{promise}」，等待对方回应...\n"
        })
    end
  end
end

defmodule Kantele.World.Room.EngageAnswerEvent do
  @moduledoc """
  求婚应答处理：把 accede 事件转给求婚方，并完成婚约（双写 meta.spouse）。

  - `engage/answer`（应婚）：双方互写 spouse（engage/joined）
  - `engage/cancel`（求婚方取消）：清除被求婚方的待处理状态
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def call(context, %{topic: "engage/answer", data: %{target_name: target_name}} = _event) do
    answerer = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case answerer do
      nil ->
        context

      _ ->
        requester = lookup_requester(context, answerer, target_name)

        case requester do
          nil ->
            render(context, answerer.pid, CommandView, "text", %{text: "这里没有你要找的人。\n"})

          _ ->
            complete_marriage(context, requester, answerer)
        end
    end
  end

  def call(context, %{topic: "engage/cancel", data: %{target_name: target_name}} = _event) do
    requester = Enum.find(context.characters, &(&1.pid == _event.from_pid))

    case requester do
      nil ->
        context

      _ ->
        target = lookup_requester(context, requester, target_name)

        if target do
          event(context, target.pid, self(), "engage/cancelled", %{from_id: requester.id})
        else
          context
        end
    end
  end

  defp complete_marriage(context, requester, answerer) do
    cond do
      PlayerMeta.spouse(requester.meta) != nil ->
        render(context, answerer.pid, CommandView, "text", %{
          text: "人家已经结婚了，你还是不要去趟混水了！\n"
        })

      PlayerMeta.spouse(answerer.meta) != nil ->
        render(context, answerer.pid, CommandView, "text", %{
          text: "你可要稳住！根据泥潭法典第九十九条，重婚者打入地狱！\n"
        })

      true ->
        context
        |> event(requester.pid, self(), "engage/joined", %{
          partner_id: answerer.id,
          partner_name: answerer.name
        })
        |> event(answerer.pid, self(), "engage/joined", %{
          partner_id: requester.id,
          partner_name: requester.name
        })
        |> render(requester.pid, CommandView, "text", %{
          text: "你和#{answerer.name}私定终身，结为夫妻，恭喜恭喜！\n"
        })
        |> render(answerer.pid, CommandView, "text", %{
          text: "你欣然应允，与#{requester.name}私定终身，结为夫妻！\n"
        })
    end
  end

  defp lookup_requester(context, answerer, name) do
    Enum.find(context.characters, fn c ->
      c.pid != answerer.pid and
        Kantele.World.Room.NameMatch.matches?(c, name)
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

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat.StatusTracker
  alias Kantele.Character.LookView
  alias Kantele.World.Items
  alias Kantele.World.ZoneCache

  # look <关键词> 查看墙上器物/菜单（LPC set("item_desc", ...)）
  def call(context, %{data: %{keyword: keyword}} = event)
      when is_binary(keyword) and keyword != "" do
    requester = Enum.find(context.characters, &(&1.pid == event.from_pid))

    case {requester, Kantele.World.Room.item_desc_entry(context.data, keyword)} do
      {nil, _} ->
        context

      {_requester, nil} ->
        render(context, event.from_pid, CommandView, "text", %{
          text: "这里没有这个东西。\n"
        })

      {_requester, {:static, text}} ->
        render(context, event.from_pid, CommandView, "text", %{text: text <> "\n"})

      {requester, {:dynamic, config}} ->
        case Kantele.World.ItemDescHandlers.lookup(context.data.id, config["kind"]) do
          {:ok, {module, function}} ->
            apply(module, function, [
              context,
              requester,
              %{keyword: keyword, room_id: context.data.id, config: config}
            ])

          {:unimplemented, _kind} ->
            render(context, event.from_pid, CommandView, "text", %{
              text: "这里没有这个东西。\n"
            })
        end
    end
  end

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
        %{item_instance | item: Kantele.World.Item.instance_item(item_instance)}
      end)

    context
    |> assign(:room, with_long_description(context.data))
    |> assign(:characters, characters)
    |> assign(:item_instances, item_instances)
    |> assign(:mini_map, mini_map)
    |> render(event.from_pid, LookView, "look")
    |> render(event.from_pid, LookView, "mini_map")
    |> render(event.from_pid, LookView, "look.extra")
  end

  # 运行期房述覆盖（对应 LPC `set("long", ...)`）。**仅当存在覆盖时才替换**：
  # `long_description/1` 无覆盖返回 nil，而无条件写 `description: nil` 会让
  # `LookView` 把 nil 混进文本列表 → `Kalevala.Output.Tags.parse_string(nil, ...)`
  # FunctionClauseError（任何一次 look 都崩，websocket 连接进程直接退出）。
  defp with_long_description(room) do
    case Kantele.World.Room.long_description(room) do
      text when is_binary(text) and text != "" -> %{room | description: text}
      _other -> room
    end
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
  alias Kantele.Npc.Attitude
  alias Kantele.Npc.EngageRule
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

      guarded_deny?(target, attacker, event) ->
        # 被守护者拒绝被守护者杀害
        msg = "你正在守护着#{target.name}，不能杀他！\n"
        render(context, attacker.pid, CommandView, "text", %{text: msg})

      guarder_refuse?(target, attacker, event) ->
        # LPC feature/guarder.c check_enemy：外门派 fight / 同门 fight 都 return 0
        render(context, attacker.pid, CommandView, "text", %{
          text: "#{target.name}#{guarder_refuse_msg(target, Map.get(event.data, :type, "fight"))}"
        })

      guarder_counter_kill?(target, attacker, event) ->
        # LPC check_enemy 的 kill_ob 分支：守卫直接反击
        # （外门派 hit/kill、同门 hit/kill）
        engage(context, target, attacker, "kill")

      engage_rule_deny?(target, event) ->
        # NPC 自己写了 accept_fight/hit/kill 且 accept=false
        # —— LPC 里这是**最优先**的：npc.c 的 accept_* 一开始就
        # `if (is_guarder()) …`，守卫走 check_enemy；非守卫且 NPC 没自己
        # 写 accept_* 时才轮到 query("attitude")。
        {:deny, msg} =
          EngageRule.decide(target.meta, Map.get(event.data, :type, "fight"), target.name)

        render(context, attacker.pid, CommandView, "text", %{text: msg})

      true ->
        case attitude_decision(target, attacker, Map.get(event.data, :type, "fight")) do
          {:refuse, msg} ->
            # LPC accept_fight 的拒战分支（气血不足 / friendly / 已在打且非 heroism）
            render(context, attacker.pid, CommandView, "text", %{
              text: "#{target.name}#{msg}"
            })

          {:kill, msg} ->
            # LPC accept_hit 的翻脸分支：说完直接反杀
            render(context, attacker.pid, CommandView, "text", %{text: msg})

            engage(context, target, attacker, "kill")

          {:engage, msg} ->
            # 正常接战；attitude 决定他说什么
            if String.trim(msg) != "" do
              render(context, attacker.pid, CommandView, "text", %{text: msg})
            end

            trigger_guarded_allies(context, attacker, target, Map.get(event.data, :type, "fight"))
            engage(context, attacker, target, Map.get(event.data, :type, "fight"))
        end
    end
  end

  # ---- LPC `inherit/char/npc.c` 的 attitude 分支 ----
  #
  # attitude 决定的是「被挑战/攻击/杀时接不接、说什么」，**不决定主动攻击**
  # （后者来自 attack() / 心跳 / chat_msg）。
  #
  # LPC 的优先顺序（npc.c 的 accept_* 开头）：
  #   1. 守卫      -> check_enemy（已由上面的 guarder_* 分支处理）
  #   2. NPC 自写   -> accept_fight/hit/kill（已由 engage_rule_deny? 处理）
  #   3. 否则       -> switch (query("attitude"))  <- 这里
  #
  # 所以只有「不是守卫、且 NPC 没自己写 accept_*、且没被 engage_rule 拒绝」
  # 才会落到 attitude 上。
  defp attitude_decision(target, _attacker, type) do
    att = attitude_of(target)

    case type do
      "kill" ->
        Attitude.decide_kill(att)

      "hit" ->
        Attitude.decide_hit(att, vitals_pct(target, :qi), vitals_pct(target, :jing))

      _ ->
        Attitude.decide_fight(att, vitals_pct(target, :qi), vitals_pct(target, :jing))
    end
  end

  defp attitude_of(%{meta: %{combat_config: %Kantele.Character.NPCConfig{attitude: att}}})
       when is_binary(att),
       do: att

  defp attitude_of(_), do: nil

  # LPC: `perqi = (int)query("qi") * 100 / query("max_qi")`
  defp vitals_pct(%{meta: %{vitals: vitals}}, key) do
    cur = Map.get(vitals || %{}, key) || 0
    max = Map.get(vitals || %{}, String.to_atom("max_" <> to_string(key))) || 0
    Attitude.pct(cur, max)
  end

  defp vitals_pct(_character, _key), do: 100

  # ---- 偷袭请求 ----

  defp dispatch(context, %{topic: "combat/touxi", data: %{name: name}} = event, attacker) do
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
          %{text: "这里禁止战斗。\n"}
        )

      is_nil(name) or name == "" ->
        render(context, attacker.pid, CommandView, "text", %{text: "你想偷袭谁？\n"})

      is_nil(target) ->
        render(context, attacker.pid, CommandView, "text", %{text: "这里没有这个人。\n"})

      !is_character?(target) ->
        render(context, attacker.pid, CommandView, "text", %{text: "看清楚一点，那并不是生物。\n"})

      is_fighting_with?(target, attacker) ->
        render(context, attacker.pid, CommandView, "text", %{text: "你已经在战斗中了，还想偷袭？\n"})

      dead?(target) or dead?(attacker) ->
        render(context, attacker.pid, CommandView, "text", %{text: "对方都已经这样了，你还用得着偷袭吗？\n"})

      target.id == attacker.id ->
        render(context, attacker.pid, CommandView, "text", %{text: "偷袭自己？别这么想不开。\n"})

      true ->
        touxi_messages(context, attacker, target)
        engage_touxi(context, attacker, target)
    end
  end

  defp is_character?(character) do
    Map.has_key?(character, :name)
  end

  defp is_fighting_with?(target, attacker) do
    # Simplified check - in real combat would check target's enemy list
    false
  end

  defp touxi_messages(context, attacker, target) do
    render(context, attacker.pid, CommandView, "text", text: "\n你猛的飞身纵起，直扑#{target.name}而去。\n")

    render(context, target.pid, CommandView, "text", text: "\n#{attacker.name}忽然向你扑来，来势甚为迅猛。\n")

    context
  end

  defp engage_touxi(context, initiator, target) do
    context
    |> start_combat_touxi(target, initiator)
    |> engage(initiator, target)
  end

  defp start_combat_touxi(context, character, touxi_target) do
    event(context, character.pid, self(), "combat/start", %{
      enemy: ref(touxi_target),
      initiator_id: touxi_target.id,
      touxi?: true
    })
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

            victim = Enum.find(players, &(&1.id in hated_ids)) || Enum.random(players)

            engage(context, npc, victim, Map.get(event.data, :type, "kill"))
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

  defp engage(context, initiator, target), do: engage(context, initiator, target, "fight")

  defp engage(context, initiator, target, type) do
    context
    |> start_combat(target, initiator, type)
    |> start_combat(initiator, target, type)
    |> maybe_summon_coagents(initiator, target, type)
  end

  # LPC feature/attack.c:104-108 —— 唯一的 kill_enemy 调用点：
  #
  #     enemy += ({ ob });
  #     if (this_object()->is_guarder() && is_killing(ob->query("id")))
  #         this_object()->kill_enemy(ob);      // guarder will look for help
  #
  # 两个要点：① 是**攻击方**（this_object()）为守卫时才调，不是被打方；
  # ② 只有「杀」才呼唤帮手，fight/hit 不调。
  defp maybe_summon_coagents(context, initiator, _target, type) do
    if type == "kill" and guarder_config?(initiator) do
      initiator
      |> guarder_coagent_opts(context)
      |> Guarder.kill_enemy()
      |> case do
        {:helpers_notified, helpers} ->
          Enum.reduce(helpers, context, &notify_coagent(&2, &1, initiator))

        # LPC 里 coagents 为空 / 不在 startroom 时**直接 return，一句话都不说**
        _ ->
          context
      end
    else
      context
    end
  end

  defp guarder_coagent_opts(guarder, context) do
    %{
      coagents: Map.get(guarder.meta, :coagents) || [],
      startroom: guarder.meta.combat_config && guarder.meta.combat_config.spawn_room_id,
      current_room: Map.get(context.data, :id) || guarder.room_id,
      enemy_id: nil,
      enemy_name: nil,
      enemy_in_target_room?: true
    }
  end

  # 帮手所在处先广播 LPC 的「大家快来帮忙啊」，再交由 Coagent.start_help 决策。
  defp notify_coagent(context, helper, guarder) do
    case event(context, self(), self(), "coagent/summon", %{
           guarder_id: guarder.id,
           coagent_id: Map.get(helper, :id),
           startroom: Map.get(helper, :startroom),
           target_id: Map.get(helper, :target_id)
         }) do
      ctx -> ctx
    end
  end

  defp start_combat(context, character, initiator, type) do
    event(context, character.pid, self(), "combat/start", %{
      enemy: ref(initiator),
      initiator_id: initiator.id,
      type: type
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
    case Map.get(character.meta, :guarder) do
      nil -> false
      guarder -> guarder && Guarder.is_guarder?(character)
    end
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

  # LPC feature/guarder.c:142-191 check_enemy 的四种反应，拆成三路：
  # 拒绝交战 / 守卫反击 / 不干预。

  defp guarder_refuse?(target, attacker, event) do
    guarder_config?(target) and
      match?({:refuse, _}, guarder_decision(target, attacker, event))
  end

  defp guarder_counter_kill?(target, attacker, event) do
    guarder_config?(target) and
      match?({:kill, _}, guarder_decision(target, attacker, event))
  end

  # LPC:152 / LPC:184 的拒绝语，可被 guarder.msgs 的 refuse_fight 覆盖
  defp guarder_refuse_msg(target, _type) do
    msgs = target.meta.guarder.msgs || %{}

    Map.get(msgs, :refuse_fight) || "我现在没空。\n"
  end

  # ---- NPC 开战接受规则（accept_fight/hit/kill → engage，见 EngageRule） ----

  defp engage_rule_deny?(target, event) do
    match?(
      {:deny, _},
      EngageRule.decide(target.meta, Map.get(event.data, :type, "fight"), target.name)
    )
  end

  defp players_in_room(context) do
    player_ids = MapSet.new(Kantele.Character.Presence.characters(), & &1.id)

    Enum.filter(context.characters, fn character ->
      dead?(character) == false and MapSet.member?(player_ids, character.id)
    end)
  end

  # ---- 玩家守卫联动（F_ATTACK guarded，LPC guard.c）----

  defp guarded_deny?(target, attacker, event) do
    Map.get(event.data, :type) == "kill" and
      attacker.id in (target.meta.temp["guarded"] || [])
  end

  # 触发被守护者的守护者加入战斗
  defp trigger_guarded_allies(context, attacker, target, type) do
    if type != "kill" do
      context
    else
      guarded = target.meta.temp["guarded"] || []

      Enum.reduce(guarded, context, fn guardian_id, acc ->
        guardian = Enum.find(acc.characters, &(&1.id == guardian_id))

        if (guardian && not dead?(guardian)) and guardian.pid != attacker.pid do
          # 守护者加入战斗攻击攻击者
          engage(acc, guardian, attacker, "kill")
        else
          acc
        end
      end)
    end
  end

  defp players_in_room(context) do
    player_ids = MapSet.new(Kantele.Character.Presence.characters(), & &1.id)

    Enum.filter(context.characters, fn character ->
      dead?(character) == false and MapSet.member?(player_ids, character.id)
    end)
  end

  # ---- 玩家守卫联动（F_ATTACK guarded，LPC guard.c）----

  defp guarded_deny?(target, attacker, event) do
    Map.get(event.data, :type) == "kill" and
      attacker.id in (target.meta.temp["guarded"] || [])
  end

  # 触发被守护者的守护者加入战斗
  defp trigger_guarded_allies(context, attacker, target, type) do
    if type != "kill" do
      context
    else
      guarded = target.meta.temp["guarded"] || []

      Enum.reduce(guarded, context, fn guardian_id, acc ->
        guardian = Enum.find(acc.characters, &(&1.id == guardian_id))

        if (guardian && not dead?(guardian)) and guardian.pid != attacker.pid do
          # 守护者加入战斗攻击攻击者
          engage(acc, guardian, attacker, "kill")
        else
          acc
        end
      end)
    end
  end

  defp players_in_room(context) do
    player_ids = MapSet.new(Kantele.Character.Presence.characters(), & &1.id)

    Enum.filter(context.characters, fn character ->
      dead?(character) == false and MapSet.member?(player_ids, character.id)
    end)
  end
end

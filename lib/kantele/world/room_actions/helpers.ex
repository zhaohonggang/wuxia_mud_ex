defmodule Kantele.World.RoomActions.Helpers do
  @moduledoc """
  P5-1b-3 handler 共享 helper：把 LPC `message_vision` / `write` 语义桥接到
  Elixir 世界模型（房间广播 / 玩家私发）。各房间移植的 `do_*` 模块复用本模块，
  避免每个 handler 重复实现广播/输出细节。

  ## 与 LPC 的对应
  - `message_vision(msg, this_player())` → `broadcast_vision/3`：向房间频道
    `rooms:\#{room_id}` 广播 `type: "vision"` 消息，房间内每人（含行动者）都收到，
    由 `Kantele.Character.VisionEvent` 按 `from_pid` 分流 echo/listen 渲染。
  - `message("vision", msg, env, ({me}))` → `broadcast_vision(conn, room_id, msg,
    exclude_actor: true)`：同样广播，但**行动者自己收不到**（LPC 用 `({me})`
    把行动者排除在接收列表外）。
  - `write(msg)` → `render_to_player/2`：只把文本推给当前玩家，不广播。
  - `this_player()->move(__DIR__"xxx")` → `move_to/2`：把玩家瞬移到目标房间。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kantele.Character.Records
  alias Kantele.Character.Teleport
  alias Kantele.World.Items

  @doc """
  `message_vision(msg, this_player())` 等价。

  把 `template` 里 LPC 的 `$N` 归一化为 `{npc}` 后，向房间频道
  `rooms:\#{room_id}` 广播 `type: "vision"` 消息。房间内每个订阅者（含行动者
  自己）都会收到；`VisionEvent` 用 `from_pid == self()` 区分 echo（行动者）/
  listen（旁观者）渲染，`VisionView` 再把 `{npc}` 渲染成「你」/行动者姓名。

  **不要在这里把 `$N` 直接替换成名字**：那样行动者会看到自己的名字而不是
  「你」，与 LPC `message_vision` 语义不符（`wield_command.ex` 的装备文案
  同样只预替换 `{name}`、把 `{npc}` 留给 `VisionView`）。

  选项：
  - `:exclude_actor`（默认 `false`）—— 为 `true` 时行动者**收不到**这条广播，
    对应 LPC `message("vision", msg, env, ({me}))`（接收列表里排除了行动者）。

  返回更新后的 `conn`（`private.channel_changes` 增加一条 publish）。
  """
  def broadcast_vision(conn, room_id, template, opts \\ [])
      when is_binary(room_id) and is_binary(template) do
    text = String.replace(template, "$N", "{npc}")

    options =
      case Keyword.get(opts, :exclude_actor, false) do
        true -> [type: "vision", meta: %{exclude_actor: true}]
        false -> [type: "vision"]
      end

    Conn.publish_message(
      conn,
      "rooms:#{room_id}",
      text,
      options,
      &__MODULE__.publish_error/2
    )
  end

  @doc """
  `write(msg)` 等价：只把文本推给当前玩家（不广播）。

  返回更新后的 `conn`（`output` 增加一条 `Conn.Text`）。
  """
  def render_to_player(conn, text) when is_binary(text) do
    entry = %Conn.Text{data: text, newline: true}
    Map.put(conn, :output, conn.output ++ [entry])
  end

  @doc """
  `this_player()->move(__DIR__"xxx")` 等价：把玩家瞬移到 `to_room_id`。

  直接委托 `Kantele.Character.Teleport.teleport/2`（死亡重生/尸体回收已在用的
  同一条路径）：改 `room_id` + 向旧房间发 `:from`、向新房间发 `:to` 两段
  Movement 事件 + 重订阅房间频道 + 触发一次 `room/look` 让玩家看到新房间。

  ## 与 LPC 的差异（纯呈现顺序，不影响结果）

  引擎的 flush 顺序是 `output` → `events`（移动 + `room/look`）→
  `channel_changes`（`message_vision` 广播）。因此：

  - `write`/`tell_object` 的文本出现在房间描述**之前**（LPC 里 `move()` 会先
    打印房间，`tell_object` 在其后 —— 顺序相反）；
  - `message_vision` 的广播一律出现在房间描述**之后**。

  玩家最终落在目标房间、旁观者在正确房间看到对应文案 —— 结果等价，只有同一
  次输入内「文案 vs 房间描述」的先后略有出入。
  """
  def move_to(conn, to_room_id) when is_binary(to_room_id) do
    Teleport.teleport(conn, to_room_id)
  end

  @doc """
  `ob = new(<item_id>); ob->move(me)`：把 `item_id` 的一件实例放进玩家背包。

  `opts[:meta]`（map）非空时合并进实例的 `meta`（对应 LPC 发放时对副本
  `obj->set("no_sell", ...)` / `obj->set("value", ...)` 的按件改写）。
  定义缺失（`{:error, :not_found}`）时不动 `conn`。

  与 NPC 侧 `Kantele.World.NpcActions.Helpers.give_item/3` 是**同一个实现**
  （后者现在委托到这里）：房间动作（如少林菩提院 `get book from hole` 取易筋经）
  与 NPC 赠礼走同一条「实例化 + 落盘 + `put_character`」链路，不重复造。
  """
  def give_item(conn, item_id, opts \\ []) do
    case Items.get(item_id) do
      {:ok, _item} ->
        instance =
          %Item.Instance{
            id: Item.Instance.generate_id(),
            item_id: item_id,
            created_at: DateTime.utc_now()
          }
          |> put_instance_meta(Keyword.get(opts, :meta, %{}))

        character = current(conn)
        character = %{character | inventory: [instance | character.inventory]}
        Records.save(character)
        put_character(conn, character)

      _ ->
        conn
    end
  end

  @doc "同 `give_item/3`，发 `count` 件（LPC 田嫂发两个包子）。"
  def give_items(conn, item_id, count, opts \\ []) when is_integer(count) and count > 0 do
    Enum.reduce(1..count, conn, fn _i, conn -> give_item(conn, item_id, opts) end)
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp put_instance_meta(instance, meta) when meta == %{} or meta == nil, do: instance

  defp put_instance_meta(instance, meta),
    do: %{instance | meta: Map.merge(instance.meta || %{}, meta)}

  @doc false
  def publish_error(conn, _error), do: conn
end

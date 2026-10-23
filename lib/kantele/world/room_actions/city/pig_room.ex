defmodule Kantele.World.RoomActions.City.PigRoom do
  @moduledoc """
  拱猪房动作：`sit` / `leave` / `deal` / `bid` / `sell` / `pass` / `play` /
  `refresh` / `skip` / `claim`（P5-4ad）。

  移植自 `inherit/room/pigroom.c` 的十个 `do_*`，以及
  `d/city/{eproom,nproom,sproom,wproom}.c`（四间房共用同一套 `add_action`）。
  牌局规则本体在纯逻辑模块 `Kantele.World.PigGame`，本模块只做三件事：

  1. **取状态**：房间 `state["pig_game"]`（`Room.get_state_by_id/2`，仅内存）。
     不存在时用 `PigGame.new/0`（对应 LPC `pig_init()`）。
  2. **分发**：按 verb 调 `PigGame.*`，得到 `{:ok, game, events}` 或 `{:error, msg}`。
  3. **落世界**：`{:ok, _}` 时写回房间状态，再按事件类型落到真实世界：

     | 事件                  | LPC 对应              | 本移植落地                              |
     | --------------------- | --------------------- | --------------------------------------- |
     | `{:vision, text}`     | `message_vision/2`    | `Helpers.broadcast_vision/3`（房间频道） |
     | `{:room, text}`       | `tell_room/2`         | `Room.tell_room/2`（`{:room_message, _}`）|
     | `{:tell, id, text}`   | `tell_object/2`       | 向 `characters:<id>` 频道订阅者 `send`   |
     | `{:temp, id, seat}`   | `set_temp`/`delete_temp` | 自己直接改；别人发 `pig/seat` 事件     |

  `{:error, msg}` 对应 LPC `notify_fail`：只给行动者本人一句提示，**不落库**
  （所以任何失败路径都不会让牌局状态产生半截变更）。

  ## 为什么 `{:temp, ...}` 要分两条路

  `meta` 只有角色自己的进程能安全修改并落盘。行动者本人的座位在本进程里直接
  改（`put_character/2` 暂存，随 conn 回写）；同桌其他人则发
  `%Kalevala.Event{topic: "pig/seat"}`，由 `Kantele.Character.PigEvent` 在各自
  进程里执行 `set_temp` / `delete_temp`。见该模块 moduledoc。

  ## 与 LPC 的差异

  - LPC `do_sit` 的「同 IP 不能同桌」检查（`query_ip_number`）未移植：本移植的
    角色结构里没有连接 IP，且该限制只影响防作弊，不影响牌局正确性。
  - LPC `after_hand` 会给玩家累加 `pig_played` / `pig_score` / `pig_head` 并
    `improve_skill("feed-power", ...)`；本移植暂无这三个持久字段，见 TODO。

  ## ⚠️ `sell` 的双重身份

  LPC 的 `do_sell` 是店铺房间自己的 action（`inherit/room/shop.c`），`sell` 并非全服
  命令，所以拱猪房里本来就没有 `sell` 可被遮蔽。本移植把卖物品做成了全局命令
  `Kantele.Character.SellCommand`（`commands.ex`，`sell` / `卖` / `变卖` / `value`），
  而房间 action 的优先级高于全局命令（对应 LPC `add_action` 的语义）。两条各自正确
  的设计撞在一起，会让四间拱猪房**内**的 `sell <物品>` 被 `do_bid` 吞掉。

  处理办法：`sell` 单独开一条 `run/2` 子句，**只有玩家真的坐在牌桌上**（牌局
  `pl` 里占着座位）才当作卖牌；否则返回 `:not_handled`（等价 LPC `return 0`），
  由 `RoomActionDispatcher` 放行给全局命令，卖物品照旧。`bid` 不走这条路——它没有
  同名全局命令，未入局时报「你没有在拱猪！」比让解析器回「什么？」更有用。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.World.PigGame
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @impl true
  # `sell` 同时也是全局命令（卖物品）。只有真的坐在牌桌上才当卖牌拦截，
  # 否则 `return 0` 交回全局命令，免得拱猪房里卖不了东西。见 moduledoc。
  def run(conn, %{verb: "sell", room_id: room_id} = params) do
    if seated?(conn, room_id), do: do_run(conn, params), else: :not_handled
  end

  def run(conn, params), do: do_run(conn, params)

  defp do_run(conn, %{verb: verb, trailing: arg, room_id: room_id}) do
    case Map.get(conn, :character) do
      %{id: id, name: name} when is_binary(id) and is_binary(room_id) ->
        player = %{id: id, name: name}

        case dispatch(verb, load(room_id), player, arg) do
          {:ok, game, events} ->
            Room.put_state_by_id(room_id, "pig_game", game)
            apply_events(conn, room_id, events)

          {:error, message} ->
            Helpers.render_to_player(conn, message)
        end

      _ ->
        :not_handled
    end
  end

  # 玩家是否占着牌桌座位（以牌局 `pl` 为准，不信 temp：temp 可能因掉线残留）。
  defp seated?(conn, room_id) when is_binary(room_id) do
    case Map.get(conn, :character) do
      %{id: id} when is_binary(id) -> PigGame.seat_of(load(room_id), id) != nil
      _ -> false
    end
  end

  defp seated?(_conn, _room_id), do: false

  # ---- 取状态 ----

  # 房间 state 里没有牌局（首次进房 / 房间进程重启）时按 `pig_init()` 初始化。
  defp load(room_id) do
    case Room.get_state_by_id(room_id, "pig_game") do
      %{stage: _} = game -> game
      _ -> PigGame.new()
    end
  end

  # ---- verb 分发（LPC `add_action` 的十个动词） ----

  defp dispatch("sit", game, player, arg), do: PigGame.sit(game, player, String.trim(arg))

  defp dispatch("leave", game, player, _arg), do: PigGame.leave(game, player)

  defp dispatch("deal", game, player, _arg), do: PigGame.deal(game, player)

  # LPC：`add_action("do_bid", "bid")` + `add_action("do_bid", "sell")`
  defp dispatch(verb, game, player, arg) when verb in ["bid", "sell"],
    do: PigGame.bid(game, player, String.trim(arg))

  defp dispatch("pass", game, player, _arg), do: PigGame.pass(game, player)

  defp dispatch("play", game, player, arg), do: PigGame.play(game, player, String.trim(arg))

  defp dispatch("refresh", game, player, _arg), do: PigGame.refresh_hand(game, player)

  defp dispatch("skip", game, player, _arg), do: PigGame.skip(game, player)

  defp dispatch("claim", game, player, arg), do: PigGame.claim(game, player, String.trim(arg))

  # 兜底：注册表只挂了上面十个动词，正常走不到这里。
  defp dispatch(_verb, _game, _player, _arg), do: {:error, "你想干什么？\n"}

  # ---- 事件落地 ----

  defp apply_events(conn, room_id, events) do
    Enum.reduce(events, conn, fn event, acc -> apply_event(acc, room_id, event) end)
  end

  defp apply_event(conn, room_id, {:vision, text}),
    do: Helpers.broadcast_vision(conn, room_id, text)

  defp apply_event(conn, room_id, {:room, text}) do
    Room.tell_room(%Room{id: room_id}, text)
    conn
  end

  defp apply_event(conn, _room_id, {:tell, player_id, text}) do
    send_to_character(player_id, {:room_message, text})
    conn
  end

  defp apply_event(conn, _room_id, {:temp, player_id, seat}), do: sync_seat(conn, player_id, seat)

  # ---- 座位 temp 同步 ----

  defp sync_seat(conn, player_id, seat) do
    character = current(conn)

    if character.id == player_id do
      meta =
        case seat do
          nil -> PlayerMeta.delete_temp(character.meta, "pigging_seat")
          s -> PlayerMeta.put_temp(character.meta, "pigging_seat", s)
        end

      put_character(conn, %{character | meta: meta})
    else
      send_to_character(player_id, %Kalevala.Event{
        from_pid: self(),
        topic: "pig/seat",
        data: %{seat: seat}
      })

      conn
    end
  end

  # `put_character/2` 只是暂存（`private.update_character`），不改 `conn.character`；
  # 同一批事件里若连着改两次（如散桌时清空所有人），必须读暂存后的那个。
  defp current(conn), do: conn.private.update_character || conn.character

  # 按 `characters:<id>` 频道找到该角色的进程并投递（`{:room_message, _}` 由
  # Foreman 渲染；`%Kalevala.Event{}` 走角色事件路由）。离线/无订阅者时静默丢弃。
  # 发给**所有**订阅者：正常只有一个（角色自己的进程），但频道注册是全局的，
  # 残留的死 pid 排在前面时只发给第一个会丢消息。
  defp send_to_character(player_id, message) when is_binary(player_id) do
    for {_channel, pid, _opts} <- Kantele.Communication.subscribers("characters:#{player_id}") do
      if is_pid(pid), do: send(pid, message)
    end

    :ok
  end

  defp send_to_character(_player_id, _message), do: :ok
end

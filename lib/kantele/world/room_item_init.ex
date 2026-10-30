defmodule Kantele.World.RoomItemInit do
  @moduledoc """
  房间内**物品**的 `init()`（LPC 玩家进入房间时，房间里每个对象都会收到 `init()` 调用）。

  LPC 里房间 `set("objects", ...)` 放进去的物品，其 `init()` 会在**有人进入房间时**
  被调用一次（与 NPC 的 `greeting()` 同一触发点，但对象是物品而不是人物）。
  本模块即这一通道的宿主，按房间 id 派发；未登记的房间返回 `conn` 原样
  （P7：零行为影响）。

  触发点在 `Kantele.Character.MoveEvent.notice/2` —— 那里每个房间成员都会收到
  一条 notice，其中「自己」那条（`conn.character` 是 `player:*`）就是**进入者**，
  也正是 LPC 里 `this_player()` 的语境。

  ## 已移植

  - `shenlong:caoping`（`d/shenlong/caoping.c` `init()`）：房间里开着断肠花
    （`shenlong:items.hua3`，别名 `duanchang hua`）时，进入即中毒：

        if (objectp(present("duanchang hua", environment(me))))
        {
            me->apply_condition("flower_poison",
                30 + (int)me->query_condition("flower_poison"));
            write(HIG "你只觉一股淡香袭来,顿时脑中一阵麻木！\\n" NOR);
        }

    毒性**累加**（已有 10 点则变 40），不是覆盖。
  """

  import Kalevala.Character.Conn, only: [get_session: 2]

  alias Kalevala.Character.Conn
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Conditions
  alias Kantele.World.Item
  alias Kantele.World.Room

  @poison_name "flower_poison"
  @poison_keyword "duanchang hua"
  @poison_base 30
  @poison_msg "你只觉一股淡香袭来,顿时脑中一阵麻木！\n"

  @doc """
  玩家进入 `room_id` 时调用，返回可能被更新过的 `conn`。

  `present_fun` 可注入（默认读房间进程的物品实例），便于单测不启房间进程。
  """
  def on_enter(conn, room_id), do: on_enter(conn, room_id, &present?/2)

  def on_enter(conn, room_id, present_fun) when room_id == "shenlong:caoping" do
    if present_fun.(room_id, @poison_keyword) do
      conn
      |> add_condition()
      |> render_poison()
    else
      conn
    end
  end

  def on_enter(conn, _room_id, _present_fun), do: conn

  # LPC `30 + (int)me->query_condition("flower_poison")`
  defp add_condition(conn) do
    current = current_poison(conn)
    ConditionEvent.grant(conn, @poison_name, %{"duration" => @poison_base + current})
  end

  defp current_poison(conn) do
    case Conditions.query_condition(%{conditions: get_session(conn, "conditions")}, @poison_name) do
      %{"duration" => d} when is_integer(d) -> d
      info when is_map(info) -> Map.get(info, "duration") || 0
      _ -> 0
    end
  end

  defp render_poison(conn) do
    entry = %Conn.Text{data: @poison_msg, newline: true}
    Map.put(conn, :output, conn.output ++ [entry])
  end

  # LPC `present("duanchang hua", environment(me))`：房间物品实例里按 id/别名匹配
  defp present?(room_id, keyword) do
    room_id
    |> Room.item_instances_by_id()
    |> Enum.any?(fn instance -> Item.matches?(definition(instance), keyword) end)
  end

  # 实例里的 `item` 是定义（可能是占位 `ItemNotLoaded`），缺定义即视为不匹配
  defp definition(%{item: %Kalevala.World.Item{} = item}), do: item
  defp definition(_), do: %Kalevala.World.Item{id: "", name: "", description: "", meta: %{}}
end

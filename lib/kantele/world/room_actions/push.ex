defmodule Kantele.World.RoomActions.Push do
  @moduledoc """
  `do_push` 系列共享原语（P5-4aj，第一批：开出口 + 内力/臂力/技能门控 + 定时关）。

  对应 LPC 关键映射：

      query("exits/<dir>") / query("gate")=="open"
        → DynamicExit.open?/2（出口是否已开；本批各房 gate/已开 标志与出口存在同步）
      me->query("neili") / set("neili", n) / add("neili", -cost)
        → meta.vitals.neili 读写
      me->query("max_neili") → meta.vitals.max_neili
      me->query_str() → Stats.query_str(meta.stats)
      me->query_skill("unarmed",1) / query_skill("force",1)
        → Stats.skill(meta.stats, name)
      room->query_temp("person_inside")>0（邻居 xiuxishi）
        → Room.snapshot(neighbor).private.characters 非空
          （与 item_desc 的 room_occupancy 判定一致）
      call_out("close_x", N) / remove_call_out("close_x")
        → DynamicExit.close_after/5（TRef 存房间 state，重开先取消）
  """
  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  def open?(room_id, dir), do: DynamicExit.open?(room_id, dir)

  def current(%{private: %{update_character: c}} = conn) when not is_nil(c), do: c
  def current(%{character: c}), do: c

  def neili(char), do: char.meta.vitals.neili
  def max_neili(char), do: char.meta.vitals.max_neili
  def str(char), do: Stats.query_str(char.meta.stats)
  def skill(char, name), do: Stats.skill(char.meta.stats, name)

  @doc "读完即删（LPC `delete_temp`）：从玩家 meta.temp 去掉某个键。"
  def consume_temp(conn, key) when is_binary(key) do
    c = current(conn)
    temp = Map.delete(c.meta.temp, key)
    put_character(conn, %{c | meta: %{c.meta | temp: temp}})
  end

  def deduct_neili(conn, cost) when cost > 0 do
    c = current(conn)
    set_neili(conn, c.meta.vitals.neili - cost)
  end

  def set_neili(conn, value) when is_integer(value) do
    c = current(conn)
    vitals = %{c.meta.vitals | neili: max(value, 0)}
    put_character(conn, %{c | meta: %{c.meta | vitals: vitals}})
  end

  @doc "邻居房是否有人占用（等价 LPC `room->query_temp(\"person_inside\") > 0`）。"
  def neighbor_occupied?(neighbor_id) do
    case Room.snapshot(neighbor_id) do
      %{private: %{characters: chars}} when is_list(chars) -> chars != []
      _ -> false
    end
  end

  @doc """
  开出口 + 播报 + 可选定时关。

  `close_targets`：`[{room_id, dir, msg}]` 列表（双向门含两边；`msg` 为 nil 静默）。
  `seconds`：>0 则登记定时器；`nil`/0 不自动关。
  """
  def reveal(conn, room_id, dir, target, vision, close_targets, seconds) do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    if is_integer(seconds) and seconds > 0 do
      DynamicExit.close_after(
        seconds * 1000,
        room_id,
        "exit_timer:push",
        close_targets,
        only_if_open: false
      )
    end

    conn
  end

  @doc "开邻居房出口（双向门用）；`message` 为 nil 不播报。"
  def set_neighbor_exit(neighbor_id, dir, target, message) do
    Room.set_exit(neighbor_id, dir, target)
    if is_binary(message) and message != "", do: Room.tell_room(%Room{id: neighbor_id}, message)
    :ok
  end

  def render(conn, text), do: Helpers.render_to_player(conn, text)
  def broadcast(conn, room_id, text), do: Helpers.broadcast_vision(conn, room_id, text)
end

defmodule Kantele.World.RoomActions.KnockPull do
  @moduledoc """
  `do_knock` / `do_pull` 系列共享原语（P5-4al）。

  这批房间（少林广场、万劫谷草地/树洞、全真弟子居/卧室、梅庄大门）共用同一形状：

      - 判参数（knock <目标> / pull <对象>，各房目标词不同）
      - 出口已开 → 提示「已经开着」（仅部分房间有此守卫）
      - 成功 → 开出口（部分双向）+ 广播 + 定时关
      - 失败（错词/无参）→ 提示「你要 X 什么」

  对应 LPC 关键映射：

      query("exits/<dir>") → `open?/2`（出口是否已开）
      set("exits/<dir>", target) / delete("exits/<dir>")
        → `DynamicExit.open/5` / `close_after/5`
      message_vision(msg, me) → `Helpers.broadcast_vision/3`（房间内广播，含行动者）
      message("vision", msg, room)（向邻房广播）
        → `Room.tell_room/2`（直发纯文本到邻房频道）
      call_out("close_x", N) / remove_call_out("close_x")
        → `DynamicExit.close_after/5`（TRef 存房间 state，重开先取消；这批各房回调
          都有 `if (!query(...)) return;` 守卫，故一律 `only_if_open: true`）
      me->set_temp("step", n) / query_temp("step")
        → `get_temp/3` / `put_temp/2`（梅庄大门铜环暗号进度，玩家级）

  ## 与 LPC 的差异

  - 部分房（万劫谷草地/树洞）对无参/错词 LPC `return 0`（静默），这里改为渲染
    「你要敲什么？/ 你要拉什么？」提示（与其他 handler 一致、更友好）。
  - 少林广场 `close_gate` 依 `present("qingfa biqiu")` 分「清法比丘/壮年僧人」两条
    播报；本引擎房间 action 无 NPC 在场查询，统一用「壮年僧人」那句（清法比丘在场
    是少数态）。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @doc "房间当前是否有该方向出口（等价 LPC `query(\"exits/<dir>\")`）。"
  def open?(room_id, dir), do: DynamicExit.open?(room_id, dir)

  def current(%{private: %{update_character: c}}) when not is_nil(c), do: c
  def current(%{character: c}), do: c

  @doc "读玩家临时标记（LPC `query_temp(key)`，默认 `nil`）。"
  def get_temp(conn, key, default \\ nil) do
    c = current(conn)
    Map.get(c.meta.temp, key, default)
  end

  @doc "写玩家临时标记（LPC `set_temp(key, value)`）。"
  def put_temp(conn, key, value) do
    c = current(conn)
    temp = Map.put(c.meta.temp, key, value)
    put_character(conn, %{c | meta: %{c.meta | temp: temp}})
  end

  @doc """
  单向开门 + 定时自关（close 仅删本房出口）。

  `close_cfg`：`{seconds, close_msg}`（秒为整数、>0；`close_msg` 为关闭时向本房
  广播的文案，空串则静默关）。`vision` 为开门时向本房广播的文案（空串则不播）。
  """
  def reveal_one(conn, room_id, dir, target, vision, {seconds, close_msg})
      when is_integer(seconds) and seconds > 0 do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    DynamicExit.close_after(
      seconds * 1000,
      room_id,
      close_timer_key(room_id),
      [{room_id, dir, close_msg}],
      only_if_open: true
    )

    conn
  end

  @doc """
  双向开门（本房 `dir`→`target`，邻房 `neighbor_dir`→`room_id`）+ 定时自关（删双向）。

  `vision` 广播到本房、`neighbor_vision` 直发邻房；`close_cfg`：
  `{seconds, self_msg, neighbor_msg}`（秒为整数、>0；两条 close 文案分别向本房 /
  邻房广播，空串则对应侧静默关）。
  """
  def reveal_both(
        conn,
        room_id,
        dir,
        target,
        neighbor_id,
        neighbor_dir,
        vision,
        neighbor_vision,
        {seconds, self_msg, neighbor_msg}
      )
      when is_integer(seconds) and seconds > 0 do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    Room.set_exit(neighbor_id, neighbor_dir, room_id)

    if is_binary(neighbor_vision) and neighbor_vision != "",
      do: Room.tell_room(%Room{id: neighbor_id}, neighbor_vision)

    DynamicExit.close_after(
      seconds * 1000,
      room_id,
      close_timer_key(room_id),
      [{room_id, dir, self_msg}, {neighbor_id, neighbor_dir, neighbor_msg}],
      only_if_open: true
    )

    conn
  end

  defp close_timer_key(room_id), do: "exit_timer:knockpull:" <> room_id
end

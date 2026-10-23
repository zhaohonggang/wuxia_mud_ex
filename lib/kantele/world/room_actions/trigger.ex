defmodule Kantele.World.RoomActions.Trigger do
  @moduledoc """
  「触发器型」`do_*` 共享原语（P5-4am）。

  这批房间（黑木崖火盆房 `do_circle`、神龙教林间 `do_kan`、侠客岛墓地 `do_mai`、
  鳌拜书房 `do_turn`、雪山禅室 `do_turn`、荆州衙门后院 `do_unlock`、衡阳水帘洞
  `do_use`、古墓密室 `do_zhan`）共用同一形状：

      if (arg != "<目标词>") return notify_fail("你要 X 什么？\\n");   // 或 return 0
      if (<条件门控>)   return notify_fail("<失败文案>\\n");
      message_vision("<成功文案>", me);
      set("exits/<dir>", target);
      remove_call_out("close");
      call_out("close", N);            // 可选：N 秒后自己合上
      me->add("neili", -cost) / destruct(ob) / set_temp(...);

  对应 LPC 关键映射：

      me->query("str") → `Stats.query_str(meta.stats)`（`str/1`）
      me->query("neili") / set("neili", n) / add("neili", -cost)
        → `meta.vitals.neili` 读写（`neili/1`、`set_neili/2`、`deduct_neili/2`）
      me->query_temp("weapon") / weapon->query("skill_type")
        → `Combat.weapon(meta.combat)` 快照（`weapon_skill_type/1`、`weapon_name/1`）
      present("<name>", me) / destruct(ob)
        → `Helpers.carries?/2` + `Helpers.take_item/2`
      query_temp("marks/x") / set_temp("marks/x", 1)
        → `meta.temp` 读写（`temp/3`、`put_temp/3`）
      call_out("close", N) / remove_call_out("close")
        → `reveal/7` 内的 `DynamicExit.close_after/5`（TRef 存房间 state，
          重开先取消；这批各房回调**都没有** `if (!query(...)) return;` 守卫，
          故一律 `only_if_open: false`）

  ## 与 LPC 的差异

  - LPC 的 `write(...)`（只给本人，如墓地 `什么？`、水帘洞点火提示）映射为
    `Helpers.render_to_player/2`；`message_vision(...)` 映射为房间广播。
  - 部分房对无参/错词 LPC `return 0`（静默放行全局命令，如水帘洞 `use`、
    鳌拜书房 `turn`），handler 直接返回 `:not_handled`。
  - 衡阳水帘洞 `do_use` 还会 `set("long", ...)` 改房间描述；转换器已把点火后的
    长描述直接写进 UCL `description`，故运行时无需再改（见该房 handler 注释）。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @timer_key_prefix "exit_timer:trigger:"

  @doc "取当前角色（`put_character` 后的未落盘版本优先，同 Push/KnockPull）。"
  def current(%{private: %{update_character: c}}) when not is_nil(c), do: c
  def current(%{character: c}), do: c

  @doc "`me->query(\"str\")`。"
  def str(char), do: Stats.query_str(char.meta.stats)

  @doc "`me->query(\"neili\")`。"
  def neili(char), do: char.meta.vitals.neili

  @doc "`me->set(\"neili\", n)`（下限 0）。"
  def set_neili(conn, value) when is_integer(value) do
    c = current(conn)
    vitals = %{c.meta.vitals | neili: max(value, 0)}
    put_character(conn, %{c | meta: %{c.meta | vitals: vitals}})
  end

  @doc "`me->add(\"neili\", -cost)`。"
  def deduct_neili(conn, cost) when is_integer(cost) and cost > 0 do
    set_neili(conn, neili(current(conn)) - cost)
  end

  @doc "装备武器的 `skill_type`（未持武器为 `nil`）。"
  def weapon_skill_type(char) do
    case Combat.weapon(char.meta.combat) do
      %{skill_type: skill_type} -> skill_type
      _ -> nil
    end
  end

  @doc "装备武器的名字（未持武器为 `nil`）。"
  def weapon_name(char) do
    case Combat.weapon(char.meta.combat) do
      %{name: name} -> name
      _ -> nil
    end
  end

  @doc "读玩家临时标记（LPC `query_temp(key)`，未设为 `default`）。"
  def temp(conn, key, default \\ nil) do
    Map.get(current(conn).meta.temp, key, default)
  end

  @doc "写玩家临时标记（LPC `set_temp(key, value)`）。"
  def put_temp(conn, key, value) do
    c = current(conn)
    temp = Map.put(c.meta.temp, key, value)
    put_character(conn, %{c | meta: %{c.meta | temp: temp}})
  end

  @doc """
  开出口 + 房间广播 + 可选定时自关。

  `vision` 为空串则不播；`close_msg` 为 nil 则静默关；`seconds` 为 nil/0 则不登记
  定时器（永久开启，如衙门后院开门、水帘洞点火）。
  """
  def reveal(conn, room_id, dir, target, vision, close_msg, seconds) do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    if is_integer(seconds) and seconds > 0 do
      DynamicExit.close_after(
        seconds * 1000,
        room_id,
        @timer_key_prefix <> room_id,
        [{room_id, dir, close_msg}],
        only_if_open: false
      )
    end

    conn
  end

  @doc "同一房间开多个出口（水帘洞 `use fire`：west + north，均无定时关）。"
  def reveal_many(conn, room_id, exits, vision \\ "") do
    conn =
      Enum.reduce(exits, conn, fn {dir, target}, acc ->
        DynamicExit.open(acc, room_id, dir, target, "")
      end)

    if is_binary(vision) and vision != "",
      do: Helpers.broadcast_vision(conn, room_id, vision),
      else: conn
  end

  def render(conn, text), do: Helpers.render_to_player(conn, text)
  def broadcast(conn, room_id, text), do: Helpers.broadcast_vision(conn, room_id, text)
end

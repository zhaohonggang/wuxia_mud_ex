defmodule Kantele.World.RoomActions.MoveStone do
  @moduledoc """
  「移像/推石/推桌」型 `do_*` 共享原语（P5-4an）。

  这批房间（峨眉华藏殿、古墓墓门、荆州乱葬岗、金蛇甬道、开封花园小筑、
  少林北林、神峰玉室、铁掌帮坟场、武当南阳宫、五毒花厅、衡阳突石）
  共用同一形状：

      if (! arg || arg != "<目标词>") return notify_fail("你要移动什么？\\n");   // 或 return 0
      if (<属性门控：臂力/内力/最大内力/基本内功/基本拳>)
          return notify_fail("<失败文案>\\n");   // 或播「纹丝不动」并把内力清零
      message_vision("<推动文案>", me);
      set("exits/<dir>", target);            // 部分房同时开邻房反向出口
      remove_call_out("close_x");
      call_out("close_x", N);                // 可选：N 秒后自己合上

  对应 LPC 关键映射：

      me->query("str") / query_str() → `Stats.query_str(meta.stats)`（`str/1`）
      me->query("neili") / set("neili", n) / add("neili", -cost)
        → `meta.vitals.neili` 读写（`neili/1`、`set_neili/2`、`deduct_neili/2`）
      me->query("max_neili") → `meta.vitals.max_neili`
      me->query_skill("force"/"unarmed", 1) → `Stats.skill(meta.stats, name)`
      me->query("family/family_name") → `meta.family.name`
      me->query_temp("marks/x") / set_temp / delete_temp
        → `meta.temp` 读写（`temp/3`、`put_temp/3`、`consume_temp/2`）
      room->query_temp("marks/x") / set_temp / delete_temp
        → 房间进程 `data.state` 同键读写（`room_temp/3`、`put_room_temp/3`、
          `delete_room_temp/2`）——与 `ItemDescHandlers.RoomTempTiers` 同源
      message("vision", msg, env, ({me})) → `broadcast_except/3`（行动者收不到）
      call_out("close_x", N) / remove_call_out
        → `reveal/6`、`reveal_both/8` 内的 `DynamicExit.close_after/5`
          （TRef 存房间 state，重开先取消；`only_if_open` 按各房回调有无
          `if (!query("exits/x")) return;` 守卫逐房传）

  ## 与 LPC 的差异

  - LPC 的 `find_object/load_object` + `objectp(room)` 判空：本引擎房间进程恒在
    监督树下，`set_exit/delete_exit` 对不存在的房间返回 `:error`，等价静默跳过。
  - 开封花园小筑 `present("yu yutong", environment(me))`：余鱼同是该房**常驻**
    NPC（`data/world/kaifeng.ucl` `room_characters`），这里用
    `Room.npc_characters_by_id/1` 实时判在场（被杀死后才放行），与 LPC 一致。
  - 少林北林 `set("break", 1)` 在 LPC 全库只写不读（死标志），不移植。
  """
  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @timer_key_prefix "exit_timer:movestone:"

  @doc "取当前角色（`put_character` 后的未落盘版本优先，同 Trigger/Push）。"
  def current(%{private: %{update_character: c}}) when not is_nil(c), do: c
  def current(%{character: c}), do: c

  @doc "`me->query(\"str\")` / `query_str()`。"
  def str(char), do: Stats.query_str(char.meta.stats)

  @doc "`me->query(\"neili\")`。"
  def neili(char), do: char.meta.vitals.neili

  @doc "`me->query(\"max_neili\")`。"
  def max_neili(char), do: char.meta.vitals.max_neili

  @doc "`me->query_skill(name, 1)`（基本技能等级）。"
  def skill(char, name), do: Stats.skill(char.meta.stats, name)

  @doc "`me->is_busy()`。"
  def busy?(char), do: Combat.busy?(char.meta.combat)

  @doc "`me->start_busy(n)`（忙乱轮数，由 combat/tick 逐轮递减）。"
  def start_busy(conn, rounds) when is_integer(rounds) and rounds > 0 do
    c = current(conn)
    combat = Combat.start_busy(c.meta.combat, rounds)
    put_character(conn, %{c | meta: %{c.meta | combat: combat}})
  end

  @doc "`me->query(\"family/family_name\")`（无门派为 nil）。"
  def family_name(char) do
    case char.meta.family do
      %{name: name} when is_binary(name) and name != "" -> name
      %{"name" => name} when is_binary(name) and name != "" -> name
      _ -> nil
    end
  end

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

  @doc "读完即删（LPC `delete_temp(key)`）。"
  def consume_temp(conn, key) do
    c = current(conn)
    temp = Map.delete(c.meta.temp, key)
    put_character(conn, %{c | meta: %{c.meta | temp: temp}})
  end

  @doc "读**房间**临时标记（LPC `room->query_temp(key)`，未设为 `default`）。"
  def room_temp(room_id, key, default \\ nil) do
    case Room.get_state_by_id(room_id, key) do
      nil -> default
      value -> value
    end
  end

  @doc "写房间临时标记（LPC `room->set_temp(key, value)`）。"
  def put_room_temp(room_id, key, value), do: Room.put_state_by_id(room_id, key, value)

  @doc "删房间临时标记（LPC `room->delete_temp(key)`）。"
  def delete_room_temp(room_id, key), do: Room.delete_state_by_id(room_id, key)

  @doc """
  批量删房间临时标记（LPC `auto_close` 里对多个房间的 `delete_temp`）。

  由 `:timer.apply_after/4` 在独立进程调用，只碰 room_id 级原语（无 `conn`）。
  """
  def clear_room_temps(pairs) when is_list(pairs) do
    Enum.each(pairs, fn {room_id, key} -> delete_room_temp(room_id, key) end)
    :ok
  end

  @doc "房间内是否有某个 NPC 在场（LPC `present(\"<name>\", environment(me))`）。"
  def npc_present?(room_id, npc_id) when is_binary(room_id) and is_binary(npc_id) do
    Enum.any?(Room.npc_characters_by_id(room_id), fn character ->
      Map.get(character, :id) == npc_id or Map.get(character, :name) == npc_id
    end)
  end

  @doc """
  开单向出口 + 房间广播 + 可选定时自关。

  选项：`:seconds`（>0 才登记定时器）、`:close_msg`（关闭时向本房广播，nil 静默）、
  `:only_if_open`（默认 `false`，对应 LPC 回调首行的 `if (!query(...)) return;` 守卫）。
  """
  def reveal(conn, room_id, dir, target, vision, opts \\ []) do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    case {Keyword.get(opts, :seconds), Keyword.get(opts, :close_msg)} do
      {seconds, close_msg} when is_integer(seconds) and seconds > 0 ->
        DynamicExit.close_after(
          seconds * 1000,
          room_id,
          @timer_key_prefix <> room_id,
          [{room_id, dir, close_msg}],
          only_if_open: Keyword.get(opts, :only_if_open, false)
        )

      _ ->
        :ok
    end

    conn
  end

  @doc """
  开双向出口（本房 `dir`→`target`，邻房 `neighbor_dir`→`room_id`）+ 可选定时自关。

  `vision` 广播到本房、`neighbor_vision` 直发邻房（`Room.tell_room`）。
  选项同 `reveal/6`：`:seconds`、`:self_msg`、`:neighbor_msg`、`:only_if_open`。
  定时关默认删**两边**（`DynamicExit.do_close_after` 的 targets 各含一条）。
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
        opts \\ []
      ) do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    Room.set_exit(neighbor_id, neighbor_dir, room_id)

    if is_binary(neighbor_vision) and neighbor_vision != "",
      do: Room.tell_room(%Room{id: neighbor_id}, neighbor_vision)

    case Keyword.get(opts, :seconds) do
      seconds when is_integer(seconds) and seconds > 0 ->
        DynamicExit.close_after(
          seconds * 1000,
          room_id,
          @timer_key_prefix <> room_id,
          [
            {room_id, dir, Keyword.get(opts, :self_msg)},
            {neighbor_id, neighbor_dir, Keyword.get(opts, :neighbor_msg)}
          ],
          only_if_open: Keyword.get(opts, :only_if_open, false)
        )

      _ ->
        :ok
    end

    conn
  end

  def render(conn, text), do: Helpers.render_to_player(conn, text)

  def broadcast(conn, room_id, text), do: Helpers.broadcast_vision(conn, room_id, text)

  @doc "房间广播但**行动者收不到**（LPC `message(\"vision\", msg, env, ({me}))`）。"
  def broadcast_except(conn, room_id, text),
    do: Helpers.broadcast_vision(conn, room_id, text, exclude_actor: true)
end

defmodule Kantele.World.RoomActions.Break do
  @moduledoc """
  `do_break` 系列共享原语（P5-4ah）。

  10 个房间（庄府大门、成都民居、福州侯门/老宅、华山石壁、金蛇山壁、凌霄冰壁、
  明教石门、侠客岛密道、神峰甬道）共用同一套形状：

      - 判参数（break <目标>，各房目标词不同）
      - 内力 / 最大内力 / 武力 门控
      - 成功 → 开出口 + 播报 + 扣内力 + 定时关（部分房间）
      - 失败 → 内力清零（+ 昏厥 / 仅播报）
      - 部分房间要持武器（华山石壁）或特定武器（神峰甬道黄金斧）

  对应 LPC 关键映射：

      query("break") / set("break",1) / delete("break")
        → 这里用 `DynamicExit.open?/2`（出口是否已开）作「已破」守卫。这些房间里
          break 标志与出口存在完全同步；自动关门（close 删出口）天然就把守卫重置，
          不需要另存房间 state。
      me->query("neili") / set("neili", n-cost) / add("neili", -cost) / set("neili", 0)
        → `meta.vitals.neili` 读写。
      me->query("max_neili") / query_skill("force", 1)
        → `meta.vitals.max_neili` / `Stats.skill(meta.stats, "force")`。
      query_temp("weapon")
        → `meta.combat.equipped[:weapon]`（武器快照，含 :name / :file）。
      me->unconcious()
        → `Damage.unconcious/1`（与陷阱 trap_event 同款 API）。
      call_out("close", N) / remove_call_out("close")
        → `DynamicExit.close_after/5`（TRef 存房间 state，重破先取消）。
  """

  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kantele.Character.Combat
  alias Kantele.Feature.Damage
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @doc "房间当前是否有该方向出口（等价于 LPC `query(\"exits/<dir>\")` / `query(\"break\")`）。"
  def open?(room_id, dir), do: DynamicExit.open?(room_id, dir)

  def current(%{private: %{update_character: c}} = conn) when not is_nil(c), do: c
  def current(%{character: c}), do: c

  def neili(char), do: char.meta.vitals.neili
  def max_neili(char), do: char.meta.vitals.max_neili
  def force_level(char), do: Stats.skill(char.meta.stats, "force")
  def wielded_weapon(char), do: get_in(char.meta.combat.equipped, [:weapon])

  @doc "当前持武器的显示名（LPC `weapon->name()` / `ob->query(\"name\")`）。"
  def weapon_name(char) do
    case wielded_weapon(char) do
      %{name: name} when is_binary(name) -> name
      _ -> ""
    end
  end

  @doc """
  卸下主手武器（LPC `ob->move(environment(me))` 的近似：武器脱手）。

  本引擎武器实例留在背包、装备只是快照，没有「掉到房间地面」的原语，所以这里只
  把 `combat.equipped[:weapon]` 清掉（对应「脱手飞出、不再握在手中」）。
  """
  def unequip_weapon(conn) do
    c = current(conn)
    combat = Combat.unequip(c.meta.combat, :weapon)
    put_character(conn, %{c | meta: %{c.meta | combat: combat}})
  end

  def set_neili(conn, value) when is_integer(value) do
    c = current(conn)
    vitals = %{c.meta.vitals | neili: max(value, 0)}
    put_character(conn, %{c | meta: %{c.meta | vitals: vitals}})
  end

  def deduct_neili(conn, cost) when cost > 0 do
    c = current(conn)
    set_neili(conn, c.meta.vitals.neili - cost)
  end

  @doc """
  开出口 + 播报 + 可选定时关。

  `close_cfg`：`{seconds, message}`（秒为整数、>0，message 为 `nil` 则静默关闭）
  或 `nil`（不自动关）。
  """
  def reveal(conn, room_id, dir, target, vision, close_cfg) do
    conn = DynamicExit.open(conn, room_id, dir, target, vision)

    case close_cfg do
      {seconds, _message} when is_integer(seconds) and seconds > 0 ->
        DynamicExit.close_after(
          seconds * 1000,
          room_id,
          "exit_timer:break",
          [{room_id, dir, close_message(close_cfg)}],
          only_if_open: false
        )

      _ ->
        :ok
    end

    conn
  end

  defp close_message({_seconds, message}), do: message

  @doc """
  LPC `me->unconcious()`（不动内力）：置 qi/jing=0、安排复活、广播晕倒。
  """
  def unconcious(conn) do
    c = current(conn)

    case Damage.unconcious(c) do
      {:ok, new_c} -> put_character(conn, new_c)
      _ -> conn
    end
  end

  @doc """
  LPC `me->die()`：死亡结算（置 qi/jing=0、安排复活、广播死亡）。

  与 `unconcious/1` 同款 API（`Damage.die/2`，无 killer）。
  """
  def die(conn) do
    c = current(conn)

    case Damage.die(c) do
      {:ok, new_c} -> put_character(conn, new_c)
      _ -> conn
    end
  end

  @doc """
  LPC `me->unconcious()`：内力清零 + 昏厥（置 qi/jing=0、安排复活、广播晕倒）。
  """
  def pass_out(conn) do
    conn
    |> set_neili(0)
    |> unconcious()
  end

  @doc "LPC `me->receive_wound(\"qi\", n)`：扣 qi（用于神峰甬道空手砸门）。"
  def wound_qi(conn, amount) when amount > 0 do
    c = current(conn)
    vitals = Vitals.wound(c.meta.vitals, :qi, amount)
    put_character(conn, %{c | meta: %{c.meta | vitals: vitals}})
  end

  # ---- 向邻房写出口 + 播报（神峰甬道劈门要同时打通对门） ----

  def open_neighbor(neighbor_id, dir, target, message) do
    Room.set_exit(neighbor_id, dir, target)
    if is_binary(message) and message != "", do: Room.tell_room(%Room{id: neighbor_id}, message)
    :ok
  end

  def render(conn, text), do: Helpers.render_to_player(conn, text)
  def broadcast(conn, room_id, text), do: Helpers.broadcast_vision(conn, room_id, text)
end

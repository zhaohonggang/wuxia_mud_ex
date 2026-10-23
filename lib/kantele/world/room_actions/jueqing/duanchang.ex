defmodule Kantele.World.RoomActions.Jueqing.Duanchang do
  @moduledoc """
  `d/jueqing/duanchang.c` 的 `do_jump`（`add_action("do_jump", ({"tiao","jump"}))`）。

  LPC 原文要点：
  - `arg` 须为 `ya` / `down`（跳崖/跳下），否则 `notify_fail("你要做什么？\\n")`。
  - busy/fighting 守卫（LPC 文案）。
  - 第一次：提示「你真的要跳下断肠崖吗…」+ `set_temp("marks/跳", 1)`，返回。
  - 第二次（temp 已置）：渲染跃崖文案 + `call_out("tell_player", random(6)+6)` →
    移动到 `underya` + `delete_temp("marks/跳")` + `unconcious()`。

  `call_out` 延时改玩家房间在引擎里走 `:timer.apply_after` 回调，回调无 `conn`，
  故复用 `trap/effect` 事件（按角色 pid 下发 `:force_move`/`:faint`/`:delete_temp`/
  `:text`），与出口陷阱同一套机制。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{verb: verb, trailing: arg, room_id: _room_id}) when verb in ["jump", "tiao"] do
    do_jump(conn, String.trim(arg))
  end

  def run(conn, _params), do: conn

  defp do_jump(conn, arg) do
    if arg not in ["ya", "down"] do
      Helpers.render_to_player(conn, "你要做什么？\n")
    else
      case guard(conn) do
        {:halt, c} -> c
        :ok -> schedule_or_confirm(conn)
      end
    end
  end

  # 第一次置标记；第二次（标记已置）真正跳崖并排程延时坠落。
  defp schedule_or_confirm(conn) do
    if PlayerMeta.get_temp(current(conn).meta, "marks/跳") do
      conn
      |> Helpers.render_to_player(
        "你鼓起勇气，纵身一跃跳下断肠崖…\n你只觉得耳边风声萧萧，浑身使不处半点力气，一颗心都提到了喉咙上。" <>
          "但见万千景致飞快地向上飞去，而感觉自己却越落越快，想不到这断肠崖竟如此之高。\n"
      )
      |> schedule_fall()
    else
      conn
      |> Helpers.render_to_player("你真的要跳下断肠崖吗，如果确定再执行一次该指令。\n")
      |> put_player_temp("marks/跳", 1)
    end
  end

  defp schedule_fall(conn) do
    pid = current(conn).pid

    effects = [
      {:text,
       "猛然间你看见下面竟有一个深潭，眼看快要落入潭中，你屏住呼吸闭住双目，只听“扑咚”一声，" <>
         "你顿感潭水冰冷刺骨，你猛地向岸边挣扎而去，终于达到了岸边，但此时你只觉得全身麻木，体力不知，眼前一片模糊…\n"},
      {:force_move, "jueqing:underya"},
      {:delete_temp, "marks/跳"},
      {:faint}
    ]

    :timer.apply_after(random_delay(6000, 6000), __MODULE__, :fire_effect, [pid, effects])
    conn
  end

  # `:timer.apply_after` 的独立进程回调：按角色 pid 下发 trap 副作用。
  def fire_effect(pid, effects) when is_pid(pid) do
    send(pid, %Event{from_pid: self(), topic: "trap/effect", data: %{effects: effects}})
    :ok
  end

  defp guard(conn) do
    c = current(conn)

    cond do
      Combat.busy?(c.meta.combat) ->
        {:halt, Helpers.render_to_player(conn, "你现在正忙着呢！\n")}

      Combat.fighting?(c.meta.combat) ->
        {:halt, Helpers.render_to_player(conn, "你还是先把你面前这个家伙解决了再说。\n")}

      true ->
        :ok
    end
  end

  defp random_delay(base, span), do: :rand.uniform(span) + base

  defp current(%{private: %{update_character: c}} = conn) when not is_nil(c), do: c
  defp current(%{character: c}), do: c

  defp put_player_temp(conn, key, value) do
    c = current(conn)
    put_character(conn, %{c | meta: PlayerMeta.put_temp(c.meta, key, value)})
  end
end

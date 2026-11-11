defmodule Kantele.Character.ClosedCommand do
  @moduledoc """
  闭关修行：`closed [stop|halt]` / `闭关 [stop|halt]`

  对应 LPC cmds/skill/closed.c 与 adm/daemons/closed.c（CLOSE_D）。

  门槛：已拜师、不在忙/战斗、潜能≥10000、qi/jing≥90%、房间 `no_fight`。
  起链后由 `Kantele.Character.ClosedStepEvent` 每拍转化：消耗潜能、增长
  combat_exp 与随机武学技能等级，直到潜能耗尽自动出关。`closed stop` 中途
  出关并返还一半已耗潜能（对应 LPC halt_closing）。

  运行态存于 `conn.session[:closed]`（随玩家进程存活，断线不保留），与
  respirate 一致；另在 `meta.temp.doing` 标记 "closed" 供外部可见。
  """

  use Kalevala.Character.Command

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.Closed
  alias Kantele.Character.ClosedStepEvent
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Room

  def run(conn, %{"rest" => rest}) do
    case String.trim(rest || "") do
      word when word in ["stop", "halt", "退出", "出关"] -> stop(conn)
      _ -> begin(conn)
    end
  end

  def run(conn, %{}), do: begin(conn)

  def run_bare(conn, _params), do: begin(conn)

  # ---------------------------------------------------------------------------
  # 起链
  # ---------------------------------------------------------------------------

  defp begin(conn) do
    character = conn.character
    room_flags = room_flags(conn, character.room_id)

    case Closed.gate(character, room_flags) do
      {:error, msg} ->
        reject(conn, msg)

      {:ok, _character} ->
        now = System.system_time(:second)

        new_meta =
          character.meta
          |> PlayerMeta.put_temp(:closed, %{started_at: now})
          |> PlayerMeta.put_temp(:doing, "closed")

        new_character = %{character | meta: new_meta}

        conn
        |> put_character(new_character)
        |> put_session(:closed, %{started_at: now})
        |> render(CommandView, "text", %{text: "你盘膝坐下，开始冥神运功，闭关修行。\n"})
        |> prompt(CommandView, "prompt", %{})
        |> broadcast_start(character.room_id)
        |> schedule_first(new_character)
    end
  end

  # ---------------------------------------------------------------------------
  # 中途出关
  # ---------------------------------------------------------------------------

  defp stop(conn) do
    case get_session(conn, :closed) do
      nil ->
        reject(conn, "你现在没有在闭关。\n")

      _state ->
        character = conn.character
        meta = character.meta
        stats = meta.stats

        # LPC halt_closing：返还一半已耗潜能（learned_points 超出 potential 的部分）
        refund = div(stats.learned_points - stats.potential, 2)
        stats = if refund > 0, do: Stats.add_potential(stats, refund), else: stats

        new_meta =
          meta
          |> Map.put(:stats, stats)
          |> PlayerMeta.put_temp(:closed, nil)
          |> PlayerMeta.put_temp(:doing, nil)

        new_character = %{character | meta: new_meta}

        conn
        |> put_character(new_character)
        |> put_session(:closed, nil)
        |> render(CommandView, "text", %{text: "你中止了闭关。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---------------------------------------------------------------------------
  # 内部工具
  # ---------------------------------------------------------------------------

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp room_flags(conn, room_id) do
    case Map.get(conn.private, :closed_room_flags) do
      nil -> Kantele.World.room_flags(room_id)
      flags when is_list(flags) -> flags
    end
  end

  defp broadcast_start(conn, room_id) when is_binary(room_id) do
    try do
      Room.tell_room(%Room{id: room_id}, "$N盘膝坐下，开始冥神运功，闭关修行。\n")
    rescue
      _ -> :ok
    end

    conn
  end

  defp broadcast_start(conn, _), do: conn

  defp schedule_first(conn, %{pid: pid} = _character) when is_pid(pid) do
    delay = Map.get(conn.private, :closed_tick, ClosedStepEvent.tick_delay())
    event = %Event{from_pid: self(), topic: ClosedStepEvent.topic(), data: %{}}
    Process.send_after(pid, event, delay)
    conn
  end

  defp schedule_first(conn, _character), do: conn
end

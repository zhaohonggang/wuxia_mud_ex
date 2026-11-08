defmodule Kantele.Character.SchemeStepEvent do
  @moduledoc """
  计划自动执行器的玩家进程定时步进（LPC cmds/usr/scheme.c 的 `execute_schedule` 心跳）。

  `scheme start` 起链后，每一拍由本模块以
  `Process.send_after(character.pid, %Kalevala.Event{topic: "character/scheme_step"})`
  投递到玩家进程，经 `Kantele.Character.Events` 路由到 `step/2`。

  控制流 / REPEAT-LOOP-BREAK / `cmd:case` 全部在 `Kantele.Character.Scheme`（纯逻辑），
  本模块只负责：失败节流、忙/死判定、强制命令执行（via `Commands.call`）、
  渲染、续拍与收尾。

  ## 与 LPC 的差异（已知，见 docs/B5）
  - **食水**：LPC 在 `food/water < 100` 时付 2000 钱补食水；本端口 `Vitals` 无
    `food/water` 字段，故跳过该闸门（恒视为满足）。
  - **`doing` 落盘**：LPC 把 `doing="scheme"` 写 dbase；本端口改用 `conn.private[:scheme]`
    作为运行态（随进程存活，断线不保留），仅用于 `clear`/`edit`/`start` 互斥。
  - **CLOSE_D**：LPC 起链时 `user_closed`、收尾时 `user_opened`；本端口 `closed` 自身为占位，
    暂不耦合。
  """
  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands
  alias Kantele.Character.Combat
  alias Kantele.Character.Scheme

  @topic "character/scheme_step"

  @doc "topic: character/scheme_step -> step/2"
  def step(conn, _event) do
    case Map.get(conn.private, :scheme) do
      nil -> conn
      state -> tick(conn, state)
    end
  end

  # ---------------------------------------------------------------------------
  # 每拍
  # ---------------------------------------------------------------------------

  defp tick(conn, state) do
    now = System.system_time(:millisecond)

    # 失败节流：RETRY 后 5 秒内静默续拍，不重复执行
    if now - Map.get(state, :last_fail, 0) < Scheme.fail_throttle() do
      schedule_next(conn, conn.character, Scheme.tick_delay())
      conn
    else
      character = current(conn)

      if busy_or_dead?(character) do
        schedule_next(conn, character, Scheme.tick_delay())
        conn
      else
        case Scheme.current_step(state) do
          :done ->
            finish(conn, "计划执行完毕。\n")

          {_idx, raw_cmd, _case_action} ->
            conn = render_step(conn, raw_cmd)

            runner = fn cmd ->
              case Commands.call(conn, cmd) do
                {:error, :unknown} -> {:error, conn}
                returned -> {:ok, returned}
              end
            end

            case Scheme.advance_step(state, runner) do
              {:done} ->
                finish(conn, "计划执行完毕。\n")

              {:done_cmd, _cmd, extra} ->
                finish(conn_or(extra, conn), "计划执行完毕。\n")

              {:ok, new_state, _cmd, extra} ->
                conn_or(extra, conn)
                |> put_scheme(new_state)
                |> schedule_next(character, Scheme.tick_delay())

              {:control, new_state} ->
                conn
                |> put_scheme(new_state)
                |> schedule_next(character, Scheme.tick_delay())

              {:retry, new_state} ->
                conn
                |> put_scheme(%{new_state | last_fail: now})
                |> schedule_next(character, Scheme.fail_throttle())

              {:ignored, new_state} ->
                conn
                |> put_scheme(new_state)
                |> schedule_next(character, Scheme.tick_delay())

              {:done_ignored} ->
                finish(conn, "计划执行完毕。\n")

              {:cancel, reason} ->
                finish(conn, reason)
            end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 忙 / 死判定（对应 LPC `is_busy()` / `living(me)`）
  # ---------------------------------------------------------------------------

  defp busy_or_dead?(character) do
    meta = Map.get(character, :meta) || %{}
    combat = Map.get(meta, :combat) || %{}
    vitals = Map.get(meta, :vitals) || %{}

    busy = Map.get(combat, :busy, 0)
    qi = Map.get(vitals, :qi, 1)
    busy > 0 or qi <= 0
  end

  # ---------------------------------------------------------------------------
  # 内部工具
  # ---------------------------------------------------------------------------

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp conn_or(:same, conn), do: conn
  defp conn_or(extra, _conn), do: extra

  defp put_scheme(conn, state) do
    Map.put(conn, :private, Map.put(conn.private, :scheme, state))
  end

  defp render_step(conn, raw_cmd) do
    # LPC: tell_object(me, me->prompt() + HIY + cmd + NOR "\n")
    conn
    |> render(CommandView, "text", %{text: raw_cmd <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp finish(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
    |> Map.put(:private, Map.delete(conn.private, :scheme))
  end

  defp schedule_next(conn, %{pid: pid} = _character, delay) when is_pid(pid) do
    event = %Event{from_pid: self(), topic: @topic, data: %{}}
    Process.send_after(pid, event, delay)
    conn
  end

  defp schedule_next(conn, _character, _delay), do: conn

  @doc "事件 topic（供 `scheme start` 起链复用）"
  def topic, do: @topic
end

defmodule Kantele.Character.ClosedStepEvent do
  @moduledoc """
  闭关心跳（对应 LPC closed.c closing() / CLOSE_D 守护进程）。

  `closed` 起链后，每一拍由本模块以
  `Process.send_after(character.pid, %Kalevala.Event{topic: "character/closed_step"})`
  投递到玩家进程，经 `Kantele.Character.Events` 路由到 `step/2`。

  每拍调用 `Kantele.Character.Closed.tick/2` 做数据转化，并把结果写回角色、
  渲染给本人、续拍；潜能耗尽或角色陷入忙/死/战斗则收尾出关。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.Closed
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records

  @topic "character/closed_step"
  @tick_interval 5000

  def tick_delay, do: @tick_interval

  def step(conn, _event) do
    case get_session(conn, :closed) do
      nil -> conn
      _state -> tick(conn)
    end
  end

  # ---------------------------------------------------------------------------
  # 每拍
  # ---------------------------------------------------------------------------

  defp tick(conn) do
    character = conn.character

    if busy_or_dead?(character) do
      finish(conn, character, ["你被人打断了闭关。\n"])
    else
      case Closed.tick(character) do
        {:done, new_character, messages} ->
          finish(conn, new_character, messages)

        {:ok, new_character, messages} ->
          conn
          |> apply_character(new_character)
          |> render_self(new_character, messages)
          |> schedule_next(character)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 收尾
  # ---------------------------------------------------------------------------

  defp finish(conn, character, messages) do
    new_meta =
      character.meta
      |> PlayerMeta.put_temp(:closed, nil)
      |> PlayerMeta.put_temp(:doing, nil)

    new_character = %{character | meta: new_meta}

    conn
    |> put_character(new_character)
    |> put_session(:closed, nil)
    |> render_self(new_character, messages)
    |> persist()
  end

  defp apply_character(conn, character) do
    conn
    |> put_character(character)
    |> persist()
  end

  # ---------------------------------------------------------------------------
  # 内部工具
  # ---------------------------------------------------------------------------

  defp render_self(conn, character, messages) do
    Enum.reduce(List.wrap(messages), conn, fn msg, acc ->
      text = String.replace(to_string(msg), "$N", character.name)

      acc
      |> render(CommandView, "text", %{text: text})
      |> prompt(CommandView, "prompt", %{})
    end)
  end

  defp busy_or_dead?(character) do
    combat = character.meta.combat
    vitals = character.meta.vitals
    Combat.busy?(combat) or Combat.fighting?(combat) or vitals.qi <= 0
  end

  defp schedule_next(conn, %{pid: pid} = _character) when is_pid(pid) do
    event = %Event{from_pid: self(), topic: @topic, data: %{}}
    Process.send_after(pid, event, @tick_interval)
    conn
  end

  defp schedule_next(conn, _character), do: conn

  defp persist(conn) do
    unless Map.get(conn.private, :closed_no_save) do
      character = conn.private.update_character || conn.character
      Records.save(character)
    end

    conn
  end

  @doc "事件 topic（供 `closed` 起链复用）"
  def topic, do: @topic
end

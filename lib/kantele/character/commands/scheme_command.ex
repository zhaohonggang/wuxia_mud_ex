defmodule Kantele.Character.SchemeCommand do
  @moduledoc """
  计划命令：`scheme [<计划文本> | edit <计划文本> | clear | show | start | stop]`

  对应 LPC cmds/usr/scheme.c。制订 / 查看 / 清除个人计划（落盘 `meta.schedule`），
  并支持 `scheme start` 自动执行：按 REPEAT/LOOP/BREAK 控制流与 `cmd:case` 失败动作，
  用 vitals/busy 自动逐步执行计划（见 `Kantele.Character.Scheme` /
  `Kantele.Character.SchemeStepEvent`）。

  已知差异（与 LPC 一致性的取舍，详见 docs/B5 §1 S5）：
  - 食水闸门：本端口 Vitals 无 food/water 字段，跳过饥饿补食逻辑。
  - 运行态：`doing` 改用 `conn.private[:scheme]`，断线不保留。
  - CLOSE_D 闭关耦合：本端口 `closed` 为占位，暂不耦合。
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Scheme
  alias Kantele.Character.SchemeStepEvent
  alias Kantele.Character.Stats

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    case arg do
      "" ->
        show(conn)

      "clear" ->
        clear(conn)

      "show" ->
        show(conn)

      "edit" ->
        render_msg(conn, "请用 scheme <计划文本> 直接制订你的计划。\n")

      "start" ->
        start(conn)

      "stop" ->
        stop(conn)

      "halt" ->
        stop(conn)

      _ ->
        text =
          case String.split(arg, ~r/\s+/, parts: 2) do
            ["edit", rest] when rest != "" -> String.trim(rest)
            _ -> arg
          end

        set(conn, text)
    end
  end

  def run(conn, %{}) do
    show(conn)
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  # ---------------------------------------------------------------------------
  # start：起链自动执行
  # ---------------------------------------------------------------------------

  defp start(conn) do
    character = conn.character
    meta = character.meta
    stats = meta.stats
    combat = meta.combat

    cond do
      is_nil(meta.schedule) or meta.schedule == "" ->
        render_msg(conn, "你目前还没有制订计划。\n")

      not is_nil(Map.get(conn.private, :scheme)) ->
        render_msg(conn, "你现在正在执行计划，不能开展新计划。\n")

      Combat.busy?(combat) ->
        render_msg(conn, "你现在正忙着呢。\n")

      Combat.fighting?(combat) ->
        render_msg(conn, "战斗中不能执行计划。\n")

      is_nil(character.room_id) ->
        render_msg(conn, "你现在什么都做不了。\n")

      true ->
        flags = safe_room_flags(character.room_id)
        player_count = room_player_count(character.room_id)

        case Scheme.start_gate(meta.schedule, flags, stats, player_count) do
          {:error, msg} ->
            render_msg(conn, msg)

          :ok ->
            new_stats = Stats.spend_potential(stats, 100)
            new_meta = %{meta | stats: new_stats}
            new_character = %{character | meta: new_meta}

            steps = Scheme.parse_steps(meta.schedule)
            state = Scheme.init_state(steps)

            conn
            |> put_character(new_character)
            |> put_scheme(state)
            |> render_msg("你开始执行计划。\n")
            |> save()
            |> schedule_first(new_character)
        end
    end
  end

  defp stop(conn) do
    case Map.get(conn.private, :scheme) do
      nil ->
        render_msg(conn, "你现在没有在执行任何计划。\n")

      _ ->
        conn
        |> Map.put(:private, Map.delete(conn.private, :scheme))
        |> render_msg("你停止了当前计划。\n")
    end
  end

  # ---------------------------------------------------------------------------
  # show / set / clear（数据层，已在前期实现）
  # ---------------------------------------------------------------------------

  defp show(conn) do
    case conn.character.meta.schedule do
      nil ->
        render_msg(conn, "你目前并没有制订任何计划。\n")

      schedule ->
        render_msg(conn, "你目前制订的计划如下：\n#{schedule}\n")
    end
  end

  defp set(conn, text) when is_binary(text) and text != "" do
    if String.length(text) > 400 do
      render_msg(conn, "你这份计划太长了，请重新设置一个短一些的。\n")
    else
      meta = %{conn.character.meta | schedule: text}
      new_conn = put_character(conn, %{conn.character | meta: meta})

      new_conn
      |> render_msg("你设置了一份新的计划。\n")
      |> save()
    end
  end

  defp set(conn, _), do: render_msg(conn, "你没有输入任何新的计划。\n")

  defp clear(conn) do
    if not is_nil(Map.get(conn.private, :scheme)) do
      render_msg(conn, "你现在正在执行计划，请先停下来再清除它。\n")
    else
      meta = %{conn.character.meta | schedule: nil}
      new_conn = put_character(conn, %{conn.character | meta: meta})

      new_conn
      |> render_msg("Ok.\n")
      |> save()
    end
  end

  # ---------------------------------------------------------------------------
  # 内部工具
  # ---------------------------------------------------------------------------

  defp put_scheme(conn, state) do
    Map.put(conn, :private, Map.put(conn.private, :scheme, state))
  end

  defp safe_room_flags(room_id) do
    try do
      Kantele.World.room_flags(room_id)
    rescue
      _ -> []
    end
  end

  defp room_player_count(room_id) do
    try do
      Kantele.Character.Presence.characters()
      |> Enum.count(fn c -> Map.get(c, :room_id) == room_id end)
    rescue
      _ -> 0
    end
  end

  defp schedule_first(conn, %{pid: pid} = _character) when is_pid(pid) do
    event = %Event{from_pid: self(), topic: SchemeStepEvent.topic(), data: %{}}
    Process.send_after(pid, event, Scheme.tick_delay())
    conn
  end

  defp schedule_first(conn, _character), do: conn

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end

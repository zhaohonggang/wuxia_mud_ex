defmodule Kantele.Character.Controllers.ToEditorController do
  @moduledoc """
  to命令的多行编辑控制器。

  在 `ToCommand` 进入编辑态后切入，负责：
  1. 累积玩家输入的多行文本
  2. 以单独一行 `.` 作为终止符
  3. 计算 neili/jing 消耗并扣除
  4. 按 verb 路由到对应频道/命令
  5. 编辑结束后切回 `CommandController`
  """

  use Kalevala.Character.Controller

  alias Kantele.Character.CommandController
  alias Kantele.Character.CommandView
  alias Kantele.Character.Events
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @max_length 4096
  @long_limit 256
  @cost_per_newline 10

  @impl true
  def init(conn) do
    editor_state = Map.get(conn.private, :to_editor)

    if is_nil(editor_state) do
      # 异常：无编辑态，直接返回命令控制器
      conn
      |> put_controller(CommandController)
    else
      conn
      |> render(CommandView, "text", %{text: "> "})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  @impl true
  def recv(conn, ".") do
    process_message(conn)
  end

  @impl true
  def recv(conn, data) do
    editor_state = Map.get(conn.private, :to_editor)
    lines = editor_state.lines ++ [data]

    new_editor = %{
      editor_state | lines: lines
    }

    conn
    |> put_private(:to_editor, new_editor)
    |> assign(:prompt, false)
    |> render(CommandView, "text", %{text: "> "})
    |> prompt(CommandView, "prompt", %{})
  end

  @impl true
  def recv(conn, ""), do: conn

  defp process_message(conn) do
    editor_state = Map.get(conn.private, :to_editor)
    verb = editor_state.verb
    target = editor_state.target
    flags = editor_state.flags
    lines = editor_state.lines

    raw_msg = Enum.join(lines, "\n")

    # 构建最终消息（对应 LPC done/4 的 APPEND_CR + opp 处理）
    msg =
      raw_msg
      |> maybe_prepend_cr(flags[:append_cr])
      |> maybe_prepend_target(target)

    # 长度检查（对应 LPC m > 4096 或 m > 256 && LIMIT_LONG）
    msg_len = String.length(msg)
    cond do
      msg_len > @max_length or (msg_len > @long_limit and flags[:limit_long]) ->
        return_cancel(conn, "你弄得这么长干什么啊？\n")

      true ->
        process_cost_and_route(conn, verb, target, msg, flags)
    end
  end

  defp process_cost_and_route(conn, verb, target, msg, flags) do
    # 消耗计算：换行符数量 × 10（对应 LPC \n → \n  replacement 产生的额外字符）
    newline_count = count_newlines(msg)
    cost = if flags[:no_cost], do: 0, else: newline_count * @cost_per_newline

    character = conn.character
    vitals = character.meta.vitals || %Vitals{}
    new_vitals = deduct_cost(vitals, cost)

    cond do
      cost > 0 and vitals.neili < cost and vitals.jing < cost ->
        return_cancel(conn, "你目前的内力和精不允许你这么做。\n")

      true ->
        new_character =
          character
          |> Map.put(:meta, %{character.meta | vitals: new_vitals})

        conn
        |> put_character(new_character)
        |> route_message(verb, target, msg, flags)
        |> put_controller(CommandController)
        |> assign(:prompt, false)
    end
  end

  defp maybe_prepend_cr(msg, true), do: "\n" <> msg
  defp maybe_prepend_cr(msg, false), do: msg

  defp maybe_prepend_target(msg, nil), do: msg
  defp maybe_prepend_target(msg, target), do: target <> " " <> msg

  defp count_newlines(msg), do: (String.split(msg, "\n") |> length()) - 1

  defp deduct_cost(%Vitals{} = vitals, 0), do: vitals

  defp deduct_cost(%Vitals{} = vitals, cost) do
    cond do
      vitals.neili >= cost ->
        %{vitals | neili: vitals.neili - cost}

      vitals.jing >= cost ->
        %{vitals | neili: 0, jing: vitals.jing - cost}

      true ->
        vitals
    end
  end

  defp route_message(conn, verb, target, msg, flags) do
    cond do
      flags[:std] ->
        route_std_command(conn, verb, target, msg)

      flags[:usr] ->
        route_usr_command(conn, verb, msg)

      true ->
        route_channel(conn, verb, msg)
    end
  end

  defp route_std_command(conn, "say", _target, msg) do
    channel_name = "rooms:#{conn.character.room_id}"
    conn
    |> event("say/send", %{text: msg})
    |> publish_to_room(channel_name, msg)
  end

  defp route_std_command(conn, "reply", _target, msg) do
    reply_to = conn.character.meta.reply_to
    conn
    |> event("tell/send", %{name: reply_to, text: msg})
  end

  defp route_std_command(conn, "tell", target, msg) do
    conn
    |> event("tell/send", %{name: target, text: msg})
  end

  defp route_usr_command(conn, "describe", msg) do
    conn
    |> event("describe/send", %{text: msg})
  end

  defp route_channel(conn, verb, msg) do
    channel_name = channel_for_verb(verb)
    conn
    |> publish_to_channel(channel_name, msg)
  end

  defp channel_for_verb("chat"), do: "chat"
  defp channel_for_verb("wiz"), do: "wiz"
  defp channel_for_verb("debug"), do: "debug"
  defp channel_for_verb("sys"), do: "sys"
  defp channel_for_verb("rumor"), do: "rumor"
  defp channel_for_verb("sing"), do: "sing"
  defp channel_for_verb("party"), do: "party"
  defp channel_for_verb("shout"), do: "shout"
  defp channel_for_verb(_), do: "chat"

  defp publish_to_room(conn, channel_name, msg) do
    # 房间频道发布通过 say/send 事件已由 SayAction 处理，此处仅确保输出
    conn
  end

  defp publish_to_channel(conn, channel_name, msg) do
    # 通过 Event.Message 发布到频道
    conn
    |> event("message/send", %{
      channel_name: channel_name,
      text: msg,
      type: "speech"
    })
  end

  defp return_cancel(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> put_controller(CommandController)
    |> assign(:prompt, false)
  end

  defp put_private(conn, key, value) do
    %{conn | private: Map.put(conn.private, key, value)}
  end
end

defmodule Kantele.Character.AssistCommand do
  @moduledoc """
  协助命令：`assist <玩家>`

  对应 LPC cmds/usr/assist.c 的简化版：
  - `assist <玩家>`：向同门玩家发出协助请求
  - `assist cancel`：取消协助请求
  - `assist accept`：接受对方的协助请求
  - `assist refuse`：拒绝对方的协助请求
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" -> query_status(conn)
      rest == "cancel" -> cancel(conn)
      rest == "accept" -> accept(conn)
      rest == "refuse" -> refuse(conn)
      true -> request_assist(conn, rest)
    end
  end

  def run(conn, %{}) do
    query_status(conn)
  end

  # 查询当前协助状态
  defp query_status(conn) do
    pending = conn.character.meta.temp["pending_assist"]
    helping = conn.character.meta.temp["assisting"]

    text =
      cond do
        pending ->
          "你正在等待 #{pending["name"]} 接受你的协助请求。\n"

        helping ->
          "你正在协助 #{helping["name"]} 完成任务。\n"

        true ->
          "你现在并没有帮助任何人。\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  # 发出协助请求
  defp request_assist(conn, target) do
    character = conn.character

    if character.meta.temp["pending_assist"] do
      conn
      |> render(CommandView, "text", %{text: "你已经发出过协助请求了，等对方回应吧。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> event("assist/request", %{name: target})
      |> assign(:prompt, false)
    end
  end

  # 取消协助请求
  defp cancel(conn) do
    pending = conn.character.meta.temp["pending_assist"]

    if pending do
      meta = Map.put(conn.character.meta, :temp, Map.delete(conn.character.meta.temp, "pending_assist"))
      character = %{conn.character | meta: meta}

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: "你打消了协助 #{pending["name"]} 的念头。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你现在并没有发出协助请求。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  # 接受对方协助
  defp accept(conn) do
    pending = conn.character.meta.temp["pending_assist_request"]

    if is_nil(pending) do
      conn
      |> render(CommandView, "text", %{text: "现在没有人请求你协助。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # 清除待处理请求
      meta = Map.put(conn.character.meta, :temp, Map.delete(conn.character.meta.temp, "pending_assist_request"))

      # 记录正在协助对方
      meta = Map.put(meta, :assisting, pending)

      character = %{conn.character | meta: meta}

      # 自动邀请对方加入队伍
      conn
      |> put_character(character)
      |> event("team/invite", %{name: pending["name"]})
      |> assign(:prompt, false)
    end
  end

  # 拒绝对方协助
  defp refuse(conn) do
    pending = conn.character.meta.temp["pending_assist_request"]

    if is_nil(pending) do
      conn
      |> render(CommandView, "text", %{text: "现在没有人请求你协助。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      meta = Map.put(conn.character.meta, :temp, Map.delete(conn.character.meta.temp, "pending_assist_request"))
      character = %{conn.character | meta: meta}

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: "你婉拒了 #{pending["name"]} 的协助请求。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end

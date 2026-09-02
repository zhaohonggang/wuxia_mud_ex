defmodule Kantele.Character.ReplyCommand do
  @moduledoc """
  回复：`reply <text>` / (对应 LPC cmds/std/reply.c)

  把 `<text>` 回复给最近一个密语你（tell）的人。收到 tell 时，接收方
  `meta.reply_to` 被 TellEvent 写成对方名字。无人密语过时提示，不崩溃。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"text" => text}) do
    case conn.character.meta.reply_to do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你要回复谁呢？\n"})
        |> prompt(CommandView, "prompt", %{})

      name ->
        conn
        |> event("tell/send", %{name: name, text: text})
        |> assign(:prompt, false)
    end
  end

  def run(conn, _params), do: run(conn, %{"text" => ""})
end
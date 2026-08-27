defmodule Kantele.Character.NickCommand do
  @moduledoc """
  昵称设置：`nick <绰号>` / `nick none`（cmds/usr/nick.c）

  Batch 6 简化：忽略 ANSI 控制字串（`$RED$` 等）插值，仅存纯文本
  中文绰号；长度按可见字符上限 30（LPC filter_color 后 <30）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        conn
        |> render(CommandView, "text", %{text: "你要替自己取什么绰号？\n"})
        |> prompt(CommandView, "prompt", %{})

      rest == "none" ->
        clear_nick(conn)

      true ->
        if String.length(rest) > 30 do
          conn
          |> render(CommandView, "text", %{text: "你的绰号太长了，想一个短一点的、响亮一点的。\n"})
          |> prompt(CommandView, "prompt", %{})
        else
          set_nick(conn, rest)
        end
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp set_nick(conn, nick) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | nickname: nick}})
    |> save
    |> render(CommandView, "text", %{text: "你取好了绰号。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp clear_nick(conn) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | nickname: nil}})
    |> save
    |> render(CommandView, "text", %{text: "你的绰号取消了。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

defmodule Kantele.Character.TitleCommand do
  @moduledoc """
  头衔展示/佩戴：`title` 查看当前头衔，`title <头衔>` 设置，`title none` 清除
  （cmds/usr/title.c 玩家展示层）

  Batch 6 简化：LPC 的巫师管理系统（-c/-d/-g/-r/-l 创建/授予/删除头衔池）
  不作实现；玩家侧只保存/展示一个自定头衔。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        show_title(conn)

      rest == "none" ->
        clear_title(conn)

      true ->
        if String.length(rest) > 30 do
          conn
          |> render(CommandView, "text", %{text: "这个头衔太长了。\n"})
          |> prompt(CommandView, "prompt", %{})
        else
          set_title(conn, rest)
        end
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp show_title(conn) do
    title = Map.get(conn.character.meta, :title, "") || ""

    text =
      cond do
        title == "" -> "你目前没有任何头衔。\n"
        true -> "你目前的头衔是：#{title}\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp set_title(conn, title) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | title: title}})
    |> save
    |> render(CommandView, "text", %{text: "你佩戴上了「#{title}」这个头衔。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp clear_title(conn) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | title: ""}})
    |> save
    |> render(CommandView, "text", %{text: "你摘下了自己的头衔。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

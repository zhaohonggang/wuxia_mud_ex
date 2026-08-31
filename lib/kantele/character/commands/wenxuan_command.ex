defmodule Kantele.Character.WenxuanCommand do
  @moduledoc """
  文选命令：`wenxuan [new|<年份> [编号]]`

  对应 LPC cmds/std/wenxuan.c。
  查看文章选集。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"arg" => arg}) do
    case String.trim(arg || "") do
      "" ->
        show_wenxuan_list(conn)

      "new" ->
        show_wenxuan_new(conn)

      _ ->
        show_wenxuan_help(conn)
    end
  end

  def run(conn, %{}) do
    show_wenxuan_list(conn)
  end

  defp show_wenxuan_list(conn) do
    conn
    |> render(CommandView, "text", %{
      text: "文章选集（使用 wenxuan new 查看最新选文）：\n\n暂无文选。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_wenxuan_new(conn) do
    conn
    |> render(CommandView, "text", %{text: "暂无最新文选。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_wenxuan_help(conn) do
    conn
    |> render(CommandView, "text", %{
      text: "指令格式：wenxuan [new|<年份> [编号]]\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end
end

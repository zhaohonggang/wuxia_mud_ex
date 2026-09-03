defmodule Kantele.Character.MemCommand do
  @moduledoc """
  内存信息命令：`mem`

  对应 LPC cmds/wiz/mem.c。
  巫师专用，显示当前游戏占用的内存数量。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    bytes = :erlang.memory(:total)

    conn
    |> render(CommandView, "text", %{
      text: "武林外传目前共使用了 #{formatted_memory(bytes)} bytes 内存。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp formatted_memory(bytes) do
    cond do
      bytes < 1024 -> "#{bytes}"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 2)} K"
      true -> "#{Float.round(bytes / (1024 * 1024), 3)} M"
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
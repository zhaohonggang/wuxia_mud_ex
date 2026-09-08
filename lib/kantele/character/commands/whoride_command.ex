defmodule Kantele.Character.WhorideCommand do
  @moduledoc """
  骑乘查询命令：`whoride`

  对应 LPC cmds/wiz/whoride.c（巫师专用）。
  列出所有当前正在骑乘坐骑的在线角色及其坐骑。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence

  def run(conn, _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        riders =
          Presence.characters()
          |> Enum.filter(fn char -> Map.get(char.meta, :riding) != nil end)

        text =
          case riders do
            [] ->
              "没有人在骑乘。\n"

            _ ->
              lines =
                Enum.map_join(riders, "\n", fn char ->
                  riding = Map.get(char.meta, :riding)
                  "#{char.name}(#{char.id}) 骑在 #{riding.name} 上。"
                end)

              "当前骑乘状态：\n#{lines}\n"
          end

        conn
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

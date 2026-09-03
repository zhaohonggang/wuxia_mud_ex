defmodule Kantele.Character.Who2Command do
  @moduledoc """
  玩家信息查询列表2：`who2`

  对应 LPC cmds/wiz/who2.c。
  巫师专用，列出所有在线角色，巫师（按权限）排在前面。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    characters = Presence.characters()
    count = length(characters)

    sorted =
      characters
      |> Enum.sort_by(fn char ->
        {-wiz_level(char), String.downcase(char.name)}
      end)

    lines =
      Enum.map_join(sorted, "\n", fn char ->
        level = wiz_level(char)
        marker = if level > 0, do: "巫师#{level} ", else: "玩家    "
        "#{marker}#{String.pad_trailing(char.name, 12)} #{char.room_id}"
      end)

    conn
    |> render(CommandView, "text", %{
      text: "在线角色查询 (who2)\n------------------------------------------------------------\n#{lines}\n------------------------------------------------------------\n共有 #{count} 位使用者连线中。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp wiz_level(char) do
    Map.get(char.attributes, "wiz_level", 0)
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
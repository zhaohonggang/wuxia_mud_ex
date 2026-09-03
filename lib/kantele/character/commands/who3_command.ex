defmodule Kantele.Character.Who3Command do
  @moduledoc """
  玩家信息查询列表3：`who3`

  对应 LPC cmds/wiz/who3.c。
  巫师专用，列出所有在线角色的六维属性（基础/有效）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence
  alias Kantele.Character.Attributes

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    characters = Presence.characters()
    count = length(characters)

    sorted =
      characters
      |> Enum.sort_by(fn char -> -wiz_level(char) end)

    lines =
      Enum.map_join(sorted, "\n", &(line(&1)))

    conn
    |> render(CommandView, "text", %{
      text: "玩家属性查询 (who3)\n----------------------------------------------\n" <>
        "玩家      悟性  根骨  身法  膂力  容貌\n" <>
        "----------------------------------------------\n" <>
        lines <>
        "----------------------------------------------\n" <>
        "#{count} 位使用者连线中。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp line(character) do
    stats = Map.get(character.meta || %{}, :stats) || %{}
    opts = %{skills: stats.skills || %{}, age: Map.get(stats, :age, 0)}

    base_int = stats.int || 0
    base_con = stats.con || 0
    base_dex = stats.dex || 0
    base_str = stats.str || 0

    eff_int = Attributes.int(base_int, opts)
    eff_con = Attributes.con(base_con, opts)
    eff_dex = Attributes.dex(base_dex, opts)
    eff_str = Attributes.str(base_str, opts)
    eff_per = Attributes.per(Map.get(stats, :per, 0) || 0, opts)

    level_marker = if wiz_level(character) > 0, do: "[W#{wiz_level(character)}]", else: "     "
    name = String.pad_trailing(character.name, 10)

    "#{name} #{level_marker} #{base_int}:#{eff_int} #{base_con}:#{eff_con} #{base_dex}:#{eff_dex} #{base_str}:#{eff_str} #{eff_per}\n"
  end

  defp wiz_level(char) do
    Map.get(char.attributes || %{}, "wiz_level", 0)
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
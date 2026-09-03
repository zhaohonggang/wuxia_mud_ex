defmodule Kantele.Character.WizlistCommand do
  @moduledoc """
  巫师名单命令：`wizlist`

  对应 LPC cmds/usr/wizlist.c。
  列出目前所有的巫师名单，按权限等级分组。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias ExVenture.Characters

  @level_titles %{
    3 => "Admin (系统管理员)",
    2 => "Arch Wizard (巫师总管)",
    1 => "Wizard (巫师)"
  }

  def run(conn, _params) do
    wizards = Characters.all_wizards()

    text = build_output(wizards)
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp build_output(wizards) do
    grouped =
      wizards
      |> Enum.group_by(& &1.wiz_level)
      |> Enum.sort_by(fn {level, _} -> -level end)

    body =
      grouped
      |> Enum.map(fn {level, chars} ->
        title = Map.get(@level_titles, level, "Level #{level}")
        names = chars |> Enum.map(& &1.name) |> Enum.map(&String.pad_trailing(&1, 10)) |> Enum.join("")

        "#{String.pad_trailing(title, 12)}: #{names}\n"
      end)
      |> Enum.join()

    """
    武林外传目前的巫师有：
    ------------------------------------------------------------------
    #{body}------------------------------------------------------------------
    """
  end
end

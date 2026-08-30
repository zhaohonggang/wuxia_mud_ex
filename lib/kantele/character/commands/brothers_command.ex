defmodule Kantele.Character.BrothersCommand do
  @moduledoc """
  结拜命令：`brothers`

  对应 LPC cmds/usr/brothers.c
  查看结拜兄弟列表。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    brothers = Map.get(character.meta, :brothers, %{})

    if map_size(brothers) == 0 do
      conn
      |> render(CommandView, "text", %{text: "你现在还没有结义的兄弟们。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      brother_list =
        brothers
        |> Enum.map(fn {id, name} -> "#{name}(#{id})" end)
        |> Enum.join(", ")

      conn
      |> render(CommandView, "text", %{text: "你现在结义的兄弟有：#{brother_list}\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end

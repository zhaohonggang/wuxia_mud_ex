defmodule Kantele.Character.DescribeCommand do
  @moduledoc """
  描述命令：`describe <描述> | none`

  对应 LPC cmds/usr/describe.c
  设置角色的长描述（别人 look 时看到的）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"description" => description}) do
    character = conn.character

    cond do
      description == "none" ->
        new_meta = Map.delete(character.meta, :long_description)

        conn
        |> put_character(%{character | meta: new_meta})
        |> render(CommandView, "text", %{text: "取消了原有的描述。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        lines = String.split(description, "\n")

        if length(lines) > 8 do
          render_error(conn, "请将您对自己的描述控制在八行以内。\n")
        else
          new_meta = Map.put(character.meta, :long_description, description)

          conn
          |> put_character(%{character | meta: new_meta})
          |> render(CommandView, "text", %{text: "设定了新的描述。\n"})
          |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

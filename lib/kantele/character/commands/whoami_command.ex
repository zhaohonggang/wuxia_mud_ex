defmodule Kantele.Character.WhoamiCommand do
  @moduledoc """
  身份查询命令：`whoami`

  对应 LPC cmds/wiz/whoami.c。
  显示当前角色的 User ID 与 Effective User ID（巫师专用）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    id = character.name

    conn
    |> render(CommandView, "text", %{
      text: "你的 User ID = #{id}\n你的 Effective User ID = #{id}\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
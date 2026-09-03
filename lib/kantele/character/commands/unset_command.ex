defmodule Kantele.Character.UnsetCommand do
  @moduledoc """
  环境变量删除命令：`unset <变数>`

  对应 LPC cmds/usr/unset.c。
  删除环境变数的设定。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"key" => key}) do
    key = String.trim(key || "")

    if key == "" do
      conn
      |> render(CommandView, "text", %{text: help_text()})
      |> prompt(CommandView, "prompt", %{})
    else
      character = conn.character
      env = Map.get(character.meta, :env, %{}) || %{}
      new_env = Map.delete(env, key)

      conn
      |> put_character(%{character | meta: %{character.meta | env: new_env}})
      |> save
      |> render(CommandView, "text", %{text: "Ok.\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: help_text()})
    |> prompt(CommandView, "prompt", %{})
  end

  defp help_text do
    """
    指令格式：unset <变数>

    这个指令让你删除环境变数的设定。
    修改变数设定请用 set 指令。
    """
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

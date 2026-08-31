defmodule Kantele.Character.SetCommand do
  @moduledoc """
  环境变量命令：`set`

  对应 LPC cmds/usr/set.c
  设置环境变量（简化版）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        list_env(conn)

      String.contains?(rest, "=") ->
        case String.split(rest, "=", parts: 2) do
          [key, value] -> set_env(conn, String.trim(key), String.trim(value))
          _ -> error(conn)
        end

      true ->
        case String.split(rest, ~r/\s+/, parts: 2) do
          [key] -> show_env(conn, key)
          [key, value] -> set_env(conn, key, value)
          _ -> error(conn)
        end
    end
  end

  def run(conn, _params) do
    list_env(conn)
  end

  defp list_env(conn) do
    env = Map.get(conn.character.meta, :env, %{}) || %{}

    if map_size(env) == 0 do
      conn
      |> render(CommandView, "text", %{text: "你目前没有设定任何环境变数。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      lines =
        env
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map_join("", fn {k, v} -> "#{k} = #{v}\n" end)

      conn
      |> render(CommandView, "text", %{text: "你目前设定的环境变数有：\n#{lines}"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_env(conn, key) do
    env = Map.get(conn.character.meta, :env, %{}) || %{}
    value = Map.get(env, key)

    if value do
      conn
      |> render(CommandView, "text", %{text: "#{key} = #{value}\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "#{key} 并没有设定。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp set_env(conn, key, value) do
    if key == "" do
      error(conn)
    else
      character = conn.character
      env = Map.get(character.meta, :env, %{}) || %{}
      new_env = Map.put(env, key, value)

      conn
      |> put_character(%{character | meta: %{character.meta | env: new_env}})
      |> save
      |> render(CommandView, "text", %{text: "#{key} 设定为 #{value}。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp error(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：set <变量> [<值>] 或 set <变量> = <值>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

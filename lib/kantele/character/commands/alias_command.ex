defmodule Kantele.Character.AliasCommand do
  @moduledoc """
  别名命令：`alias`

  对应 LPC cmds/usr/alias.c
  设置命令别名。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    if rest == "" do
      list_aliases(conn)
    else
      case String.split(rest, ~r/\s+/, parts: 2) do
        [verb] ->
          delete_alias(conn, verb)

        [verb, replacement] ->
          set_alias(conn, verb, replacement)
      end
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp list_aliases(conn) do
    alias_map = Map.get(conn.character.meta, :alias_commands, %{})

    if map_size(alias_map) == 0 do
      conn
      |> render(CommandView, "text", %{text: "你目前并没有设定任何 alias。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      alias_list =
        alias_map
        |> Enum.map(fn {k, v} -> "#{k} = #{v}" end)
        |> Enum.join("\n")

      conn
      |> render(CommandView, "text", %{text: "你目前设定的 alias 有：\n#{alias_list}\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp set_alias(conn, verb, replacement) do
    character = conn.character
    alias_map = Map.get(character.meta, :alias_commands, %{})

    cond do
      verb == "alias" ->
        conn
        |> render(CommandView, "text", %{text: "你不能将 \"alias\" 指令设定其他用途。\n"})
        |> prompt(CommandView, "prompt", %{})

      verb == "" ->
        conn
        |> render(CommandView, "text", %{text: "你要设什么 alias？\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        new_alias_map = Map.put(alias_map, verb, replacement)

        conn
        |> put_character(%{character | meta: %{character.meta | alias_commands: new_alias_map}})
        |> save
        |> render(CommandView, "text", %{text: "今后你用 #{verb} 来替代 #{replacement} 命令。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp delete_alias(conn, verb) do
    character = conn.character
    alias_map = Map.get(character.meta, :alias_commands, %{})

    if Map.has_key?(alias_map, verb) do
      new_alias_map = Map.delete(alias_map, verb)

      conn
      |> put_character(%{character | meta: %{character.meta | alias_commands: new_alias_map}})
      |> save
      |> render(CommandView, "text", %{text: "你取消了 #{verb} 这个替代命令。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "你目前并没有设定这个 alias。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

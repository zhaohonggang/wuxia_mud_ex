defmodule Kantele.Character.AliasCommand do
  @moduledoc """
  自定义别名：`alias` / `alias <动词>`（删除）/ `alias <新> <替换>`
  （cmds/usr/alias.c）

  替换串支持 `$1`/`$2`…/`$*` 参数占位：输入别名时用后续参数代入，
  再交给命令路由器解析（见 `CommandController.recv/2` 的展开钩子）。

  Batch 6 简化：不可覆盖系统中已有的动词或 `alias` 本身（与 LPC 一致）；
  不做原命令 `COMMAND_D->find_command` 的路径归属判断。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Commands
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        list_aliases(conn)

      true ->
        case String.split(rest, ~r/\s+/, parts: 2) do
          [verb] ->
            delete_alias(conn, verb)

          [verb, replacement] when replacement != "" ->
            set_alias(conn, verb, replacement)

          _ ->
            conn
            |> render(CommandView, "text", %{text: "你要设什么 alias？\n"})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp list_aliases(conn) do
    aliases = Map.get(conn.character.meta, :alias_commands, %{}) || %{}

    text =
      if map_size(aliases) == 0 do
        "你目前并没有设定任何 alias。\n"
      else
        rows =
          aliases
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.map_join("", fn {verb, replace} ->
            String.pad_trailing(verb, 15) <> " = " <> replace <> "\n"
          end)

        "你目前设定的 alias 有：\n#{rows}"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp set_alias(conn, verb, replacement) do
    cond do
      verb == "alias" ->
        conn
        |> render(CommandView, "text", %{text: "你不能将 \"alias\" 指令设定其他用途。\n"})
        |> prompt(CommandView, "prompt", %{})

      system_verb?(verb) ->
        conn
        |> render(CommandView, "text", %{text: "动词 #{verb} 是一个常用命令，你不能替代它。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        character = conn.character
        aliases = Map.get(character.meta, :alias_commands, %{}) || %{}

        conn
        |> put_character(%{character | meta: %{character.meta | alias_commands: Map.put(aliases, verb, replacement)}})
        |> save
        |> render(CommandView, "text", %{text: "今后你用 #{verb} 来替代 #{replacement} 命令。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp delete_alias(conn, verb) do
    character = conn.character
    aliases = Map.get(character.meta, :alias_commands, %{}) || %{}

    text =
      if Map.has_key?(aliases, verb) do
        "你取消了 #{verb} 这个替代命令。\n"
      else
        "你目前并没有设定 #{verb} 这个 alias。\n"
      end

    conn
    |> put_character(%{character | meta: %{character.meta | alias_commands: Map.delete(aliases, verb)}})
    |> save
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp system_verb?(verb) do
    case Commands.parse(verb) do
      {:ok, _command} -> true
      _ -> false
    end
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

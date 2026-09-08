defmodule Kantele.Character.PromoteCommand do
  @moduledoc """
  提升权限命令：`promote <玩家> <等级>`

  对应 LPC cmds/arch/promote.c（arch 专用）。
  将玩家的巫师等级（0=玩家 1=巫师 2=天神 3=管理员）写入数据库，
  重新登录后生效（LPC 的即时 `setup()` 在 Elixir 中改为重登生效）。
  arch 只能提升到不高于自身等级。
  """

  use Kalevala.Character.Command

  import Ecto.Query

  alias ExVenture.Characters
  alias ExVenture.Characters.Character
  alias ExVenture.Repo
  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView

  @max_level 3

  def run(conn, params) do
    character = conn.character

    case Access.archwizp(character) do
      false ->
        return_error(conn, "你没有天神的权限。\n")

      true ->
        do_promote(conn, character, params["arg"])
    end
  end

  defp do_promote(conn, character, rest) do
    case parse_args(rest) do
      :error ->
        return_error(conn, "指令格式：promote <玩家> <等级>\n")

      {:ok, name, level} ->
        cond do
          level < 0 or level > @max_level ->
            return_error(conn, "没有这种等级。\n")

          Access.wiz_level(character) < level ->
            return_error(conn, "你没有这种权力。\n")

          true ->
            update_level(conn, name, level)
        end
    end
  end

  defp update_level(conn, name, level) do
    case find_player(name) do
      nil ->
        return_error(conn, "你只能改变玩家的权限。\n")

      player ->
        case Characters.update(player, %{wiz_level: level}) do
          {:ok, _} ->
            conn
            |> render(CommandView, "text", %{
              text: "你将 #{name} 的权限提升为 #{level} 级巫师。（重新登录后生效）\n"
            })
            |> prompt(CommandView, "prompt", %{})

          {:error, _} ->
            return_error(conn, "修改失败。\n")
        end
    end
  end

  defp find_player(name) do
    Repo.one(from c in Character, where: c.name == ^name, limit: 1)
  end

  defp parse_args(nil), do: :error

  defp parse_args(rest) when is_binary(rest) do
    case String.split(String.trim(rest), ~r/\s+/, parts: 2, trim: true) do
      [name, level_str] ->
        case Integer.parse(level_str) do
          {level, ""} -> {:ok, name, level}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_args(_), do: :error

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

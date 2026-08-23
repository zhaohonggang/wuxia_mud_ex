defmodule Kantele.Character.PerformCommand do
  @moduledoc """
  绝招命令：`perform <技能>.<招式>`

  两种写法等价：

  - `perform liuxin-jian.liu`（技能 id）
  - `perform sword.liu`（map_skill 的用法，映射到柳心剑法）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  def run(conn, %{"action" => action}) do
    case String.split(String.trim(action), ".") do
      [key, move] ->
        resolve(conn, String.trim(key), String.trim(move))

      _ ->
        conn
        |> render(CommandView, "text", %{text: "用法：perform <武功>.<招式>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp resolve(conn, key, move) do
    stats = conn.character.meta.stats

    skill_id =
      cond do
        Skills.known?(key) -> key
        true -> Stats.mapped(stats, key)
      end

    module = skill_id && Skills.get(skill_id)

    cond do
      is_nil(module) ->
        render_error(conn, "你并没有使用这项武功。\n")

      true ->
        case Map.get(module.perform_list(), move) do
          nil ->
            render_error(conn, "这项武功中没有这一招。\n")

          perform_module ->
            perform_module.run(conn)
        end
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

defmodule Kantele.Character.EnableCommand do
  @moduledoc """
  技能映射命令：`enable <用法> <特技>`

  对应 LPC map_skill：如 `enable sword liuxin-jian` 后，剑法攻击与
  招架都会使用柳心剑法的招式表。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Combat.Skills

  def run(conn, params) do
    character = conn.character
    usage = params["usage"]
    skill_id = params["skill"]
    module = Skills.get(skill_id)

    cond do
      is_nil(module) ->
        render_error(conn, "没有这项武功。\n")

      not module.valid_enable(usage) ->
        render_error(conn, "#{skill_title(skill_id)}不能enable到这个用法。\n")

      true ->
        stats = %{character.meta.stats | mapped: Map.put(character.meta.stats.mapped, usage, skill_id)}
        character = %{character | meta: %{character.meta | stats: stats}}
        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{
          text: "你决定用#{skill_title(skill_id)}作为#{usage_title(usage)}。\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  defp skill_title("liuxin-jian"), do: "柳心剑法"
  defp skill_title("liuxi-neigong"), do: "柳溪内功"
  defp skill_title(other), do: other

  defp usage_title("sword"), do: "剑法"
  defp usage_title("parry"), do: "招架"
  defp usage_title("force"), do: "内功"
  defp usage_title(other), do: other
end

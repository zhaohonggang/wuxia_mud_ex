defmodule Kantele.Character.ExertCommand do
  @moduledoc """
  运功命令：`exert powerup`（走 map_skill 的 force 映射）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  def run(conn, params) do
    function = Map.get(params, "function", "")
    stats = conn.character.meta.stats

    skill_id = Stats.mapped(stats, "force")
    module = skill_id && Skills.get(skill_id)

    exert_module = module && Map.get(module.exert_list(), String.trim(function))

    case exert_module do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你不会这种运功方法。\n"})
        |> prompt(CommandView, "prompt", %{})

      exert_module ->
        exert_module.run(conn)
    end
  end
end

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

    exert_module =
      if module do
        Map.get(module.exert_list(), String.trim(function))
      end

    # 公共运功 fallback（F4）：force 映射的内功里没有、或尚未激发内功时，
    # 查基本内功「force」的共用运功列表（kungfu/skill/force/power.c 等）。
    exert_module =
      exert_module ||
        case Skills.get("force") do
          nil -> nil
          force_module -> Map.get(force_module.exert_list(), String.trim(function))
        end

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

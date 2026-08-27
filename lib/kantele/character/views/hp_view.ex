defmodule Kantele.Character.HpView do
  @moduledoc """
  hp 命令的展示（assigns 为命令层展开后的纯值）
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("display", assigns) do
    %EventText{
      topic: "Character.Hp",
      data: assigns,
      text: render("_display", assigns)
    }
  end

  def render("_display", assigns) do
    %{vitals: vitals, potential: potential, learned_points: learned_points} = assigns
    food = Map.get(vitals, :food, 0)

    """
    ╔════════════════════════════════════════════
    ║ {room-title}#{assigns.name}{/room-title}
    ╠════════════════════════════════════════════
    ║ 精气：{sp}#{vitals.jing}/#{vitals.max_jing}{/sp}　精力：#{vitals.jingli}/#{vitals.max_jingli}
    ║ 气血：{hp}#{vitals.qi}/#{vitals.max_qi}{/hp}　内力：{ep}#{vitals.neili}/#{vitals.max_neili}{/ep}
    ║ 食物：#{food}　潜能：#{max(potential - learned_points, 0)}
    ║ 实战经验 #{assigns.combat_exp}
    ╚════════════════════════════════════════════
    """
  end
end

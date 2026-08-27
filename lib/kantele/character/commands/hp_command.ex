defmodule Kantele.Character.HpCommand do
  @moduledoc """
  状态命令：`hp`（cmds/usr/hp.c）

  展示精气/气血/内力/食物/饮水/潜能等数值。简化为只显示自身状态，
  不做 LPC 的 -m/-g 巫师参数与怒气/死亡保护明细。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.HpView

  def run(conn, _params) do
    character = conn.character
    stats = character.meta.stats

    conn
    |> render(HpView, "display", %{
      name: character.name,
      vitals: character.meta.vitals,
      combat_exp: stats.combat_exp,
      potential: stats.potential,
      learned_points: stats.learned_points || 0
    })
  end
end

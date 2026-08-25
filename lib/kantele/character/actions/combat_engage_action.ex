defmodule Kantele.Character.CombatEngageAction do
  @moduledoc """
  aggressive NPC 主动开战（brain 节点 `actions/combat-engage`）

  向房间发 `combat/aggressive`，由房间挑选在场玩家开战。
  对应 LPC combatd.c auto_fight/start_aggressive。
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, _data) do
    # 携带仇恨名单（A9/P11）：房间优先对记仇目标开战，无则随机挑人
    hated_ids = Kantele.Character.Combat.attacked_by_ids(conn.character.meta.combat)

    conn
    |> event("combat/aggressive", %{hated_ids: hated_ids})
    |> assign(:prompt, false)
  end

  def publish_error(conn, _error), do: conn
end

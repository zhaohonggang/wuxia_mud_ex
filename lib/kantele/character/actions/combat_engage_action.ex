defmodule Kantele.Character.CombatEngageAction do
  @moduledoc """
  aggressive NPC 主动开战（brain 节点 `actions/combat-engage`）

  向房间发 `combat/aggressive`，由房间挑选在场玩家开战。
  对应 LPC combatd.c auto_fight/start_aggressive。
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, _data) do
    conn
    |> event("combat/aggressive")
    |> assign(:prompt, false)
  end

  def publish_error(conn, _error), do: conn
end

defmodule Kantele.Character.DuelCommand do
  @moduledoc """
  决斗命令：`duel <目标>` / `决斗 <目标>`

  向目标发起公开决斗：双方互记为 competitor（F_ATTACK competitor）后立即开战。
  决斗以一方战败告终（死亡/倒地即分出胜负），与切磋（fight）不同，胜负会广播。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    conn
    |> event("combat/attack", %{name: params["name"], type: "duel"})
    |> assign(:prompt, false)
  end
end
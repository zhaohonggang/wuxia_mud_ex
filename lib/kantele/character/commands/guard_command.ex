defmodule Kantele.Character.GuardCommand do
  @moduledoc """
  守卫命令：`guard [<目标>|cancel]`

  三种模式：
  - `guard <玩家>`：保护玩家，被保护者受到攻击时自动加入战斗
  - `guard <物品>`：守住地上的物品，防止他人拿走
  - `guard <方向>`：守住某出口，阻止所有人从该出口离开
  - `guard cancel`：取消守卫状态
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target}) do
    character = conn.character

    if character.meta.combat.enemies != [] do
      conn
      |> render(CommandView, "text", %{text: "你现在没有办法分心去做这类事！\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case String.trim(target) do
        "" ->
          show_guard_status(conn)

        "cancel" ->
          cancel_guard(conn)

        target ->
          conn
          |> event("guard/guard", %{target: target})
          |> assign(:prompt, false)
      end
    end
  end

  defp show_guard_status(conn) do
    guardfor = conn.character.meta.temp["guardfor"]

    text =
      case guardfor do
        nil ->
          "指令格式：guard <生物> | <物品> | <方向>\n"

        %{type: "character", id: id, name: name} ->
          "你正在守护着#{name}。\n"

        %{type: "item", id: _id, name: name} ->
          "你正守在#{name}一旁，防止别人拿走。\n"

        %{type: "exit", name: exit_name} ->
          "你正守住往#{exit_name}的方向，不准任何人离开。\n"

        _ ->
          "指令格式：guard <生物> | <物品> | <方向>\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp cancel_guard(conn) do
    conn
    |> event("guard/cancel", %{})
    |> render(CommandView, "text", %{text: "什么也不用守了，真是好轻松。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

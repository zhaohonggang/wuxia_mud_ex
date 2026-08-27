defmodule Kantele.Character.FleeCommand do
  @moduledoc """
  逃跑命令：`flee` / `逃跑`

  对应 LPC cmds/std/go.c 中的 `do_flee()`：战斗中尝试随机出口逃跑。
  复用已有 FleeEvent 机制：room/flee → RandomExitEvent 提供出口列表 →
  FleeEvent 随机选一个 → request_movement 执行移动。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character

    cond do
      not Combat.fighting?(character.meta.combat) ->
        fail(conn, "你现在没有在战斗，不用逃跑。\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "你正忙着呢，无法逃跑。\n")

      true ->
        conn
        |> event("room/flee")
        |> assign(:prompt, false)
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

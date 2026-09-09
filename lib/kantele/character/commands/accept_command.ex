defmodule Kantele.Character.AcceptCommand do
  @moduledoc """
  接受命令：`accept`

  对应 LPC cmds/std/accept.c
  接受「神秘挑战者」的挑战：若当前房间有摆擂的挑战者，则报名应战并立即开打
  （走房间 `combat/attack` 真实战斗）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.World.Story.Challenger

  def run(conn, _params) do
    character = conn.character

    cond do
      Combat.fighting?(character.meta.combat) ->
        conn
        |> render(CommandView, "text", %{text: "你正在与人过招，还是专心对敌吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        case Challenger.current(character.room_id) do
          nil ->
            conn
            |> render(CommandView, "text", %{text: "现在没有人来挑战。\n"})
            |> prompt(CommandView, "prompt", %{})

          challenger ->
            :ok = Challenger.accept(%{id: character.id, name: character.name})

            conn
            |> render(CommandView, "text", %{text: "你纵身跃上擂台，对着挑战者抱拳一礼。\n"})
            |> event("combat/attack", %{name: challenger.name, type: "fight"})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end
end
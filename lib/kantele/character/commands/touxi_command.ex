defmodule Kantele.Character.TouxiCommand do
  @moduledoc """
  偷袭命令：`touxi <目标>`

  对应 LPC cmds/std/touxi.c。
  偷袭敌人，不成时会被反击。经验低的玩家偷袭高的会只打一下并招反，
  经验高者偷袭低者连续三下。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"name" => name}) do
    character = conn.character

    cond do
      is_nil(name) or name == "" ->
        conn
        |> render(CommandView, "text", %{text: "你想偷袭谁？\n"})
        |> prompt(CommandView, "prompt", %{})

      character.attributes["ghost"] == true ->
        conn
        |> render(CommandView, "text", %{text: "你这个样子有什么好偷袭的？\n"})
        |> prompt(CommandView, "prompt", %{})

      is_busy?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你的动作还没有完成，不能偷袭。\n"})
        |> prompt(CommandView, "prompt", %{})

      is_fighting?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你已经在战斗中了，还想偷袭？\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        conn
        |> event("combat/touxi", %{name: name})
        |> assign(:prompt, false)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你想偷袭谁？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp is_busy?(character) do
    combat = character.meta.combat
    (combat && combat.busy && combat.busy > 0) || character.attributes["doing"]
  end

  defp is_fighting?(character) do
    combat = character.meta.combat
    combat && combat.enemies != []
  end
end

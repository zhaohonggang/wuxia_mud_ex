defmodule Kantele.Character.SpattackCommand do
  @moduledoc """
  会心一击命令：`spattack [<对象>]`

  对应 LPC cmds/skill/spattack.c：
  已婚玩家与伴侣联手攻击正在交手的对手。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, params) do
    character = conn.character
    _arg = params["arg"] || ""

    cond do
      is_no_fight_room?(character.room_id) ->
        fail(conn, "这里不能战斗。\n")

      true ->
        do_spattack(conn, character)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp is_no_fight_room?(room_id) do
    "no_fight" in Kantele.World.room_flags(room_id)
  end

  defp do_spattack(conn, character) do
    spouse = character.meta.spouse

    if is_nil(spouse) do
      fail(conn, "你还没有伴侣，使什么会心一击？\n")
    else
      conn
      |> render(CommandView, "text", %{text: "你心中默默思念着#{spouse.name}，试图与其心灵相通...\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

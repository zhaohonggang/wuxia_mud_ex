defmodule Kantele.Character.PersuadeCommand do
  @moduledoc """
  渡世济人命令：`persuade|quanjia <人物> stop`

  对应 LPC cmds/skill/persuade.c：
  峨嵋派技能，劝说战斗中的NPC停止战斗。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, params) do
    character = conn.character
    arg = params["arg"] || ""

    case parse_args(arg) do
      {:ok, who, :stop} ->
        do_persuade(conn, character, who)

      :error ->
        fail(conn, "指令格式：persuade|quanjia <人物> stop\n")
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp parse_args(arg) do
    case Regex.run(~r/^(.+)\s+stop$/, String.trim(arg)) do
      [_, who] -> {:ok, String.trim(who), :stop}
      nil -> :error
    end
  end

  defp do_persuade(conn, character, who_name) do
    if not is_emei?(character) do
      fail(conn, "只有峨嵋派才能用渡世济人！\n")
    else
      conn
      |> render(CommandView, "text", %{text: "你摇摇了头，慢慢地向#{who_name}走过去，双手合十，开始念诵佛经...\n\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp is_emei?(character) do
    family = character.meta.family
    family && family["family_name"] == "峨嵋派"
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

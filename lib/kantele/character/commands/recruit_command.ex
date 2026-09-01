defmodule Kantele.Character.RecruitCommand do
  @moduledoc """
  收徒命令：`recruit|shou [cancel]|<对象>`

  对应 LPC cmds/skill/recruit.c：
  收某人为弟子，如果对方已经答应拜师（pending/apprentice）。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, params) do
    character = conn.character
    arg = params["arg"] || ""

    cond do
      arg == "cancel" ->
        do_cancel(conn, character)

      arg == "" ->
        fail(conn, "指令格式：recruit|shou [cancel]|<对象>\n")

      true ->
        do_recruit(conn, character, arg)
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp do_cancel(conn, character) do
    pending = character.meta.team_pending

    if pending && pending["recruit"] do
      new_meta = %{character.meta | team_pending: Map.delete(pending, "recruit")}
      new_conn = put_character(conn, %{character | meta: new_meta})

      new_conn
      |> render(CommandView, "text", %{text: "你改变主意不想收人为弟子了。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      fail(conn, "你现在并没有收录任何人为弟子的意思。\n")
    end
  end

  defp do_recruit(conn, character, target_name) do
    if is_nil(character.meta.family) do
      fail(conn, "你并不属于任何门派，你必须先加入一个门派，或自己创一个才能收徒。\n")
    else
      conn
      |> render(CommandView, "text", %{text: "你想收#{target_name}为弟子。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

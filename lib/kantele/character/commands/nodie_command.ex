defmodule Kantele.Character.NodieCommand do
  @moduledoc """
  死亡保护命令：`nodie`

  对应 LPC cmds/wiz/nodie.c（巫师专用）。
  将自身的气血/精神/精力/内力恢复到全满，并挂起死亡保护。
  因无对象系统，暂仅支持自身。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def run(conn, _params) do
    character = conn.character

    cond do
      !Access.wizardp(character) ->
        return_error(conn, "你没有巫师的权限。\n")

      PlayerMeta.get_temp(character.meta, "guard_death") == 1 ->
        return_error(conn, "你已处于死亡保护状态。\n")

      true ->
        character =
          character
          |> restore_vitals()
          |> put_guard_death()

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: "你面露拈花之色，口中念念有词，说不尽的慈祥安和。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp restore_vitals(character) do
    vitals = character.meta.vitals

    vitals = %{
      vitals
      | qi: vitals.max_qi,
        jing: vitals.max_jing,
        jingli: vitals.max_jingli,
        neili: vitals.max_neili
    }

    %{character | meta: Map.put(character.meta, :vitals, vitals)}
  end

  defp put_guard_death(character) do
    meta = PlayerMeta.put_temp(character.meta, "guard_death", 1)
    %{character | meta: meta}
  end

  defp return_error(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
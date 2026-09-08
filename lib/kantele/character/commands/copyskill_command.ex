defmodule Kantele.Character.CopyskillCommand do
  @moduledoc """
  复制武功命令：`copyskill <玩家>`

  对应 LPC cmds/wiz/copyskill.c（巫师专用，简化版）。
  挑选一位当前在线玩家，把其武功技能、特技映射、绝招、战斗经验与
  根基属性复制到自身。LPC 的 `to <目的>` 会写入他人角色
  （跨角色运行态在 Elixir 中不可行），此处只支持复制给自己。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence
  alias Kantele.Character.Records

  def run(conn, params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        do_copy(conn, character, params["arg"])
    end
  end

  defp do_copy(conn, character, rest) do
    case find_source(rest) do
      nil ->
        return_error(conn, "这里没有这位玩家。\n")

      source ->
        updated = copy_skills(character, source)
        Records.save(updated)

        conn
        |> put_character(updated)
        |> render(CommandView, "text", %{
          text: "你口中念念有词，一道红光笼罩了你，你学会了 #{source.name} 的武功。\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp find_source(nil), do: nil

  defp find_source(rest) do
    name = String.trim(rest)

    Enum.find(Presence.characters(), fn char ->
      char.meta && char.meta.stats && (char.name == name or char.id == name)
    end)
  end

  defp copy_skills(character, source) do
    src = source.meta.stats
    own = character.meta.stats

    stats = %{
      own
      | skills: src.skills || %{},
        mapped: src.mapped || %{},
        performs: src.performs || MapSet.new(),
        combat_exp: src.combat_exp || 0,
        str: src.str || 0,
        dex: src.dex || 0,
        con: src.con || 0,
        int: src.int || 0
    }

    combat =
      %{character.meta.combat | jiali: (source.meta.combat && source.meta.combat.jiali) || 0}

    %{character | meta: %{character.meta | stats: stats, combat: combat}}
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
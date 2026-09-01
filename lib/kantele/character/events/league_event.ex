defmodule Kantele.Character.LeagueEvent do
  @moduledoc """
  结社（帮派）事件处理（角色侧）：

  - `league/joined`（被收取成员）：写入 meta.league（含 grant=0）并加入 inter 频道
  - `league/removed`（被开除成员 / 自己 out）：清除 meta.league 并可选的 grant 提示
  - `league/dismissed`（同盟解散）：清除 meta.league
  - `league/grant`（权限变更）：更新 meta.league.grant
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records

  def joined(conn, %{data: %{league_name: league_name, leader_id: leader_id, leader_name: leader_name}}) do
    character = conn.character

    league = %{
      league_name: league_name,
      leader_id: leader_id,
      leader_name: leader_name,
      grant: 0,
      set: %{no_kill: 0, weiwang: 0, follow: 0}
    }

    meta = PlayerMeta.put_league(character.meta, league)

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "你加入了「#{league_name}」。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def removed(conn, %{data: %{league_name: league_name}}) do
    character = conn.character

    meta =
      if PlayerMeta.league(character.meta) && PlayerMeta.league(character.meta)[:league_name] == league_name do
        PlayerMeta.put_league(character.meta, nil)
      else
        character.meta
      end

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "你已离开了「#{league_name}」。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def dismissed(conn, %{data: %{league_name: league_name}}) do
    character = conn.character

    meta =
      if PlayerMeta.league(character.meta) && PlayerMeta.league(character.meta)[:league_name] == league_name do
        PlayerMeta.put_league(character.meta, nil)
      else
        character.meta
      end

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "「#{league_name}」已经解散。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def grant(conn, %{data: %{grant: grant}}) do
    character = conn.character
    league = PlayerMeta.league(character.meta)

    meta =
      if league do
        PlayerMeta.put_league(character.meta, %{league | grant: grant})
      else
        character.meta
      end

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "你的帮派权限被调整为：#{grant_show(grant)}\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp grant_show(0), do: "无权限"
  defp grant_show(1), do: "★ 招人"
  defp grant_show(2), do: "★★ 战斗"
  defp grant_show(3), do: "★★★ 踢人"
  defp grant_show(4), do: "★★★★ 高阶"
  defp grant_show(_), do: "无权限"

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
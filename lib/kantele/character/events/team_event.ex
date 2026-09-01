defmodule Kantele.Character.TeamEvent do
  @moduledoc """
  队伍（cmds/std/team.c）的角色侧事件处理。

  - `team/invite-request`（被邀者）：记录 pending 并提示接受/拒绝
  - `team/declined`（队长）：提示对方拒绝
  - `team/set`（全员）：写入队伍结构
  - `team/disband`（全员）：队长解散后清空
  - `team/kicked`（被踢者）：清空自身队伍
  - `team/member-left`（其余成员）：从成员列表移除离开者
  - `team/talk`（全员）：队伍会话
  - `team/formation`（全员）：设置阵形（队员移动解除）
  - `team/xp-share`（队员）：分享击杀经验/潜能
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Team

  def invite_request(conn, %{data: %{leader: leader}}) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | team_pending: leader}})
    |> render(CommandView, "text", %{
      text: "#{leader.name}邀请你加入队伍，输入 team accept 接受 / team refuse 拒绝。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  def declined(conn, %{data: %{accepter_name: name}}) do
    conn
    |> render(CommandView, "text", %{text: "#{name}拒绝了你的队伍邀请。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # 被邀者接受：队长创建/扩充队伍并广播 team/set 给双方
  def accept(conn, %{data: %{accepter: accepter}} = _event) do
    character = conn.character
    current = Map.get(character.meta, :team)

    team =
      case current do
        %{leader_pid: leader_pid} when leader_pid == character.pid ->
          if Team.member?(current, accepter.id),
            do: current,
            else: Team.add_member(current, accepter)

        nil ->
          Team.new(character)

        _other ->
          # 只有队长能接纳入队
          current
      end

    if team != current do
      target_pids = team.members |> Enum.map(& &1.pid)

      conn
      |> broadcast_set(team, target_pids)
      |> render(CommandView, "text", %{text: "#{accepter.name}加入了你的队伍。\n"})
    else
      render(conn, CommandView, "text", %{text: "对方无法加入你的队伍。\n"})
    end
    |> prompt(CommandView, "prompt", %{})
  end

  def refuse(conn, %{data: %{accepter: accepter}}) do
    render(conn, CommandView, "text", %{text: "#{accepter.name}拒绝了你的邀请。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def swear(conn, %{data: %{leader_name: leader_name, leader_id: leader_id, name: name}}) do
    character = conn.character

    league = %{
      league_name: name,
      leader_id: leader_id,
      leader_name: leader_name,
      grant: 0,
      set: %{no_kill: 0, weiwang: 0, follow: 0}
    }

    meta = PlayerMeta.put_league(character.meta, league)

    conn
    |> put_character(%{character | meta: meta})
    |> render(CommandView, "text", %{text: "#{leader_name}振臂一呼：我们结义成盟，共立「#{name}」！\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def set_team(conn, %{data: %{team: team}}) do
    character = conn.character

    conn
    |> put_character(%{character | meta: %{character.meta | team: team, team_pending: nil}})
    |> render(CommandView, "text", %{text: "你加入了队伍。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def disband(conn, %{data: %{leader_name: leader_name}}) do
    character = conn.character
    team = Map.get(character.meta, :team)

    conn =
      if team && Map.get(team, :formation) do
        render(conn, CommandView, "text", %{text: "#{leader_name}将队伍解散了，阵形也随之解除。\n"})
      else
        render(conn, CommandView, "text", %{text: "#{leader_name}将队伍解散了。\n"})
      end

    conn
    |> clear_team
    |> prompt(CommandView, "prompt", %{})
  end

  def kicked(conn, _data) do
    conn
    |> render(CommandView, "text", %{text: "你被请出了队伍。\n"})
    |> clear_team
    |> prompt(CommandView, "prompt", %{})
  end

  def member_left(conn, %{data: %{member_id: member_id, member_name: member_name}}) do
    character = conn.character
    team = Map.get(character.meta, :team)

    cond do
      is_nil(team) ->
        conn

      Map.get(team, :formation) != nil ->
        conn
        |> render(CommandView, "text", %{text: "#{member_name}离开了队伍，阵形解除。\n"})
        |> put_team(clear_formation(team, member_id))

      true ->
        conn
        |> render(CommandView, "text", %{text: "#{member_name}离开了队伍。\n"})
        |> put_team(Kantele.Character.Team.remove_member(team, member_id))
    end
    |> prompt(CommandView, "prompt", %{})
  end

  def talk(conn, %{data: %{from_name: from_name, text: text}}) do
    conn
    |> render(CommandView, "text", %{text: "【队伍】#{from_name}：#{text}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def formation(conn, %{data: %{formation_name: name}}) do
    character = conn.character
    team = Map.get(character.meta, :team)

    conn
    |> put_team(Map.put(team, :formation, name))
    |> render(CommandView, "text", %{text: "队长将全队组成了「#{name}」阵形。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def xp_share(conn, %{data: %{exp: exp, potential: potential}}) do
    character = conn.character
    stats = %{character.meta.stats | combat_exp: character.meta.stats.combat_exp + (exp || 0)}
    stats = %{stats | potential: stats.potential + (potential || 0)}
    character = put_character_meta(character, stats)

    conn
    |> put_character(character)
    |> save
    |> render(CommandView, "text", %{text: "你分享了队友的经验 #{exp || 0}、潜能 #{potential || 0}。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp put_character_meta(character, stats),
    do: %{character | meta: %{character.meta | stats: stats}}

  defp clear_team(conn) do
    character = conn.character
    put_character(conn, %{character | meta: %{character.meta | team: nil, team_pending: nil}})
  end

  defp broadcast_set(conn, team, target_pids) do
    character = conn.character

    conn =
      put_character(conn, %{character | meta: %{character.meta | team: team, team_pending: nil}})

    Enum.each(target_pids, fn pid ->
      if pid != character.pid && Process.alive?(pid) do
        send(pid, %Kalevala.Event{from_pid: self(), topic: "team/set", data: %{team: team}})
      end
    end)

    conn
  end

  defp put_team(conn, team) do
    character = conn.character
    put_character(conn, %{character | meta: %{character.meta | team: team}})
  end

  defp clear_formation(team, _member_id) when is_nil(team), do: nil

  defp clear_formation(team, member_id) do
    %{team | formation: nil, members: Enum.reject(team.members, &(&1.id == member_id))}
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

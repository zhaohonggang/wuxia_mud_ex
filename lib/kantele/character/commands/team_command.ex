defmodule Kantele.Character.TeamCommand do
  @moduledoc """
  队伍（cmds/std/team.c）：`team <子命令>` / `组队 <子命令>`

  子命令：with 邀请、accept 接受、refuse 拒绝、dismiss 解散/离开、kick 踢出、
  talk 队伍会话、list 名单、form 阵形、kill 全队攻击、swear 结义（简化）。

  Batch 6 在 Kantele 架构内的落地：
  - 队伍结构存 `meta.team`（运行态），成员间直接 pid 通信
  - `with`/`kill` 需要房间内解析目标 → 走 Room 事件
  - 队长移动自动带队员跟随（见 MoveEvent）
  - 击杀经验分享（见 CombatEvent.enemy_died 钩子）
  """

  use Kalevala.Character.Command

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Team

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    case parse_cmd(rest) do
      {:ok, "", nil} ->
        list_team(conn)

      {:ok, verb, arg} ->
        dispatch(conn, verb, arg)

      :error ->
        conn
        |> render(CommandView, "text", %{text: "你要发什么队伍命令？\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp parse_cmd("") do
    {:ok, "", nil}
  end

  defp parse_cmd(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [verb, arg] -> {:ok, verb, arg}
      [verb] -> {:ok, verb, nil}
    end
  end

  defp dispatch(conn, verb, arg) do
    case verb do
      "with" ->
        invite(conn, arg)

      "accept" ->
        accept(conn)

      "refuse" ->
        refuse(conn)

      "dismiss" ->
        dismiss(conn)

      "kick" ->
        kick(conn, arg)

      "talk" ->
        talk(conn, arg)

      "say" ->
        talk(conn, arg)

      "list" ->
        list_team(conn)

      "form" ->
        form(conn, arg)

      "kill" ->
        kill(conn, arg)

      "swear" ->
        swear(conn, arg)

      _ ->
        conn
        |> render(CommandView, "text", %{text: "你要发什么队伍命令？\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---- 邀请 / 接受 / 拒绝 ----

  defp invite(conn, target) when is_binary(target) and target != "" do
    conn
    |> event("team/invite", %{name: target})
    |> assign(:prompt, false)
  end

  defp invite(conn, _) do
    render_text(conn, "你想和谁成为伙伴？\n")
  end

  defp accept(conn) do
    case Map.get(conn.character.meta, :team_pending) do
      nil ->
        render_text(conn, "你现在并没有收到任何队伍邀请。\n")

      leader ->
        send(leader.pid, %Event{
          from_pid: self(),
          topic: "team/accept",
          data: %{accepter: Team.ref(conn.character)}
        })

        assign(conn, :prompt, false)
    end
  end

  defp refuse(conn) do
    case Map.get(conn.character.meta, :team_pending) do
      nil ->
        render_text(conn, "你现在并没有收到任何队伍邀请。\n")

      leader ->
        send(leader.pid, %Event{
          from_pid: self(),
          topic: "team/refuse",
          data: %{accepter: Team.ref(conn.character)}
        })

        character = conn.character

        conn
        |> put_character(%{character | meta: %{character.meta | team_pending: nil}})
        |> render_text("#{leader.name}的邀请已被你拒绝。\n")
    end
  end

  # ---- 解散 / 离开 / 踢出 ----

  defp dismiss(conn) do
    case Map.get(conn.character.meta, :team) do
      nil ->
        render_text(conn, "你现在并没有参加任何队伍。\n")

      team ->
        character = conn.character

        if Team.leader?(team, character.pid) do
          notify_all(team, character.pid, "team/disband", %{leader_name: character.name})
          conn |> clear_own_team |> render_text("你将队伍解散了。\n")
        else
          notify_all(team, character.pid, "team/member-left", %{
            member_id: character.id,
            member_name: character.name
          })

          conn
          |> clear_own_team
          |> render_text("你脱离了你的队伍。\n")
        end
    end
  end

  defp kick(conn, target) when is_binary(target) and target != "" do
    case Map.get(conn.character.meta, :team) do
      nil ->
        render_text(conn, "你现在并没有参加任何队伍。\n")

      team ->
        character = conn.character

        cond do
          not Team.leader?(team, character.pid) ->
            render_text(conn, "只有队伍领袖可以踢人。\n")

          true ->
            case Enum.find(team.members, &name_match?(&1, target)) do
              nil ->
                render_text(conn, "队伍里没有 #{target}。\n")

              member ->
                notify_all(team, character.pid, "team/member-left", %{
                  member_id: member.id,
                  member_name: member.name
                })

                if Process.alive?(member.pid) do
                  send(member.pid, %Event{from_pid: self(), topic: "team/kicked", data: %{}})
                end

                assign(conn, :prompt, false)
            end
        end
    end
  end

  defp kick(conn, _), do: render_text(conn, "踢谁？\n")

  # ---- 会话 ----

  defp talk(conn, text) when is_binary(text) and text != "" do
    case Map.get(conn.character.meta, :team) do
      nil ->
        render_text(conn, "你现在并没有和别人组成队伍。\n")

      team ->
        character = conn.character

        if Process.alive?(character.pid) do
          send(character.pid, %Event{
            from_pid: self(),
            topic: "team/talk",
            data: %{from_name: character.name, text: text}
          })
        end

        notify_all(team, character.pid, "team/talk", %{from_name: character.name, text: text})
        assign(conn, :prompt, false)
    end
  end

  defp talk(conn, _), do: render_text(conn, "队伍会话格式：team talk <讯息>。\n")

  # ---- 名单 ----

  defp list_team(conn) do
    case Map.get(conn.character.meta, :team) do
      nil ->
        render_text(conn, "你现在并没有参加任何队伍。\n")

      team ->
        alive = Team.alive_members(team)
        names = Enum.map_join(alive, "\n  ", &("- " <> &1.name))
        formation = if Map.get(team, :formation), do: "（阵形：#{team.formation}）", else: ""
        leader_name = leader_name(team)
        render_text(conn, "你现在队伍中的成员有：\n  #{names}#{formation}\n队长：#{leader_name}\n")
    end
  end

  # ---- 阵形 ----

  defp form(conn, array) when is_binary(array) and array != "" do
    case Map.get(conn.character.meta, :team) do
      nil ->
        render_text(conn, "你必须是一个队伍的领袖才能组织阵形。\n")

      team ->
        character = conn.character

        cond do
          not Team.leader?(team, character.pid) ->
            render_text(conn, "你必须是一个队伍的领袖才能组织阵形。\n")

          Kantele.Character.Stats.skill(character.meta.stats, array) == 0 ->
            render_text(conn, "这种阵形你没学过。\n")

          true ->
            notify_all(team, character.pid, "team/formation", %{formation_name: array})
            render_text(conn, "你将全队组成了「#{array}」阵形。\n")
        end
    end
  end

  defp form(conn, _), do: render_text(conn, "队伍阵形格式：team form <阵法>。\n")

  # ---- 全队攻击 ----

  defp kill(conn, target) when is_binary(target) and target != "" do
    case Map.get(conn.character.meta, :team) do
      nil ->
        render_text(conn, "你这个队伍中现在没有别人，想出手就直接下 kill 命令吧。\n")

      team ->
        character = conn.character

        if Team.leader?(team, character.pid) do
          conn
          |> event("team/attack", %{name: target, team: Team.alive_members(team)})
          |> assign(:prompt, false)
        else
          render_text(conn, "只有队伍的领袖才能下命令攻击别人。\n")
        end
    end
  end

  defp kill(conn, _), do: render_text(conn, "你想率领队伍攻击谁？\n")

  # ---- 结义（简化）----

  defp swear(conn, name) when is_binary(name) and name != "" do
    character = conn.character
    weiwang = character.meta.stats.weiwang || 0

    cond do
      Map.get(character.meta, :team) == nil ->
        render_text(conn, "你现在并不在队伍中啊。\n")

      weiwang < 20000 ->
        render_text(conn, "你在江湖上名气还不够，聚帮结众还是以后再说吧。\n")

      String.length(name) < 4 or String.length(name) > 12 ->
        render_text(conn, "结义的名字长度需在 4-12 个字符之间。\n")

      true ->
        # 简化：即时结义，不逐人投票（LPC 的 LEAGUE_D 同盟库不存在 -> 不作持久化）
        team = Map.get(character.meta, :team)
        notify_all(team, character.pid, "team/swear", %{leader_name: character.name, name: name})
        render_text(conn, "你们结义成盟，共立「#{name}」！\n")
    end
  end

  defp swear(conn, _), do: render_text(conn, "结义前先想好一个名字吧！\n")

  # ---- helpers ----

  defp notify_all(team, self_pid, topic, data) do
    Enum.each(team.members, fn member ->
      if member.pid != self_pid && Process.alive?(member.pid) do
        send(member.pid, %Event{from_pid: self(), topic: topic, data: data})
      end
    end)
  end

  defp clear_own_team(conn) do
    character = conn.character
    put_character(conn, %{character | meta: %{character.meta | team: nil, team_pending: nil}})
  end

  defp leader_name(team) do
    case Enum.find(team.members, &(&1.pid == team.leader_pid)) do
      nil -> "未知"
      leader -> leader.name
    end
  end

  defp name_match?(member, name) do
    member.name == name || String.starts_with?(member.name, name)
  end

  defp render_text(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

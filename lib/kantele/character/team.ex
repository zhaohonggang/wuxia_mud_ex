defmodule Kantele.Character.Team do
  @moduledoc """
  队伍（cmds/std/team.c）的纯数据辅助。

  队伍结构（存于每个成员的 `PlayerMeta.team`，运行态）：

      %{id: "team_xxx", leader_pid: pid, members: [%{id, name, pid}]}

  队伍成员共享同一份 `members` 列表；leader 由 `leader_pid` 标识。
  玩家进程死亡/中途退出会催熟成员列表，读侧二者都做兜底。
  """

  def new(leader) do
    %{id: id(), leader_pid: leader.pid, members: [ref(leader)], formation: nil}
  end

  def size(team), do: length(team.members)

  def leader?(%{leader_pid: leader_pid}, pid), do: leader_pid == pid

  def member?(team, id) do
    Enum.any?(team.members, &(&1.id == id))
  end

  def add_member(team, member) do
    %{team | members: team.members ++ [ref(member)]}
  end

  def remove_member(team, id) do
    %{team | members: Enum.reject(team.members, &(&1.id == id))}
  end

  def alive_members(team) do
    Enum.reject(team.members, &(not Process.alive?(&1.pid)))
  end

  def alive_pids(team) do
    team
    |> alive_members()
    |> Enum.map(& &1.pid)
  end

  def ref(%{id: id, pid: pid, name: name}), do: %{id: id, pid: pid, name: name}

  @doc """
  follow_me 跟随判定（对应 `feature/team.c follow_me/2` 的纯决策部分）

  - `ob_id` == leader → 跟随 leader（受 no_follow + 身法 dex 判定）
  - `ob_id` == team[0]（成员首位）→ 跟随队伍领袖
  其余不跟随。返回 `{:follow, role}` 或 `:no_follow`。
  """
  def follow?(team, ob_id, opts \\ %{}) do
    leader_id = Map.get(team, :leader_id)
    first_id = first_member_id(team) || leader_id

    cond do
      ob_id == leader_id ->
        if Map.get(opts, :no_follow, false) and outrun?(opts) do
          :no_follow
        else
          {:follow, :leader}
        end

      ob_id == first_id ->
        {:follow, :team}

      true ->
        :no_follow
    end
  end

  defp first_member_id(team) do
    case Enum.at(team.members, 0) do
      nil -> nil
      first -> first.id || first.pid
    end
  end

  defp outrun?(opts) do
    my_dex = Map.get(opts, :dex, 0)
    other_dex = Map.get(opts, :leader_dex, 0)
    div(my_dex, 2) + :rand.uniform(max(my_dex + 1, 1)) < other_dex
  end

  def id() do
    <<a, b, c>> = :crypto.strong_rand_bytes(3)
    "team_" <> Base.encode16(<<a, b, c>>, case: :lower)
  end
end

defmodule Kantele.World.NpcActions.NpcAttack do
  @moduledoc """
  NPC 主动出手 / 开战 helper（P5-1c，full `bi`）。

  对应 LPC NPC 脚本里的 `kill_ob(target)` 与 `COMBAT_D->do_attack(npc, target)`
  （见 `d/tulong/tulong/npc/{chang,guo}.c`）。本引擎没有通用的 `kill_ob` 起步 API
  （`Kantele.Feature.Attack.kill_ob/2` 是死代码），故直接复用心跳战斗的事件契约：

  - `strike/3` —— 单次攻击：给目标发 `combat/incoming`（攻击方只出招，命中/伤害
    由目标进程以其完整状态结算，见 `Kantele.Character.CombatEvent`）。
  - `kill_ob/2` —— 互相开战：给双方各发 `combat/start`（`type: "kill"`）。

  `npc`/`target` 皆为**房间快照**角色（含 `:pid`/`:id`/`:name`/`:room_id`）。
  """

  alias Kalevala.Event
  alias Kantele.Combat.Fighter

  @doc "LPC `ref(ob)`：`%{id, pid, name, room_id}` 快照"
  def ref(%{id: id, pid: pid, name: name, room_id: room_id}),
    do: %{id: id, pid: pid, name: name, room_id: room_id}

  @doc "NPC 出手一击（`COMBAT_D->do_attack`）：目标进程结算同普通战斗"
  def strike(npc, target, jiali_paid \\ 0) do
    if alive?(target) do
      send(
        target.pid,
        %Event{
          from_pid: npc_pid(npc),
          topic: "combat/incoming",
          data: %{attacker: ref(npc), fighter: Fighter.from_character(npc), jiali_paid: jiali_paid}
        }
      )

      :ok
    else
      {:error, :no_process}
    end
  end

  @doc "互相开战（`obj->kill_ob(me); me->kill_ob(obj)`）：双方各收 `combat/start`"
  def kill_ob(npc, target) do
    cond do
      not alive?(npc) -> {:error, :no_process}
      not alive?(target) -> {:error, :no_process}
      true ->
        send(target.pid, %Event{
          from_pid: npc.pid,
          topic: "combat/start",
          data: %{enemy: ref(npc), initiator_id: npc.id, type: "kill"}
        })

        send(npc.pid, %Event{
          from_pid: npc.pid,
          topic: "combat/start",
          data: %{enemy: ref(target), initiator_id: npc.id, type: "kill"}
        })

        :ok
    end
  end

  defp npc_pid(%{pid: pid}) when is_pid(pid), do: pid
  defp npc_pid(_npc), do: self()

  defp alive?(%{pid: pid}) when is_pid(pid), do: true
  defp alive?(_), do: false
end

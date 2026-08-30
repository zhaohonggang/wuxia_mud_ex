defmodule Kantele.Character.CoagentEvent do
  @moduledoc """
  帮手（coagent）事件处理（对应 `feature/coagent.c`）

  `coagent/help`：受保护的 NPC（mate）被攻击时，投递给其登记在案的帮手。
  帮手以自身实时状态跑 `Coagent.start_help/1` 决策：

    - `{:noop}` / `{:already}`：不动
    - `{:fight, id}`：已在目标房间，就地参战
    - `{:move, room, id}`：异地，瞬移至目标房间后参战

  战斗与移动副作用由宿主在事件层执行（复用 `Teleport` 与 `combat/start`）。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.Teleport
  alias Kantele.Npc.Coagent

  @doc "帮手被召唤（mate 受击）：决策并执行移动/参战"
  def help(conn, %{data: %{attacker: attacker, mate_room: mate_room}}) do
    character = conn.character
    combat = character.meta.combat

    cond do
      dead?(character) ->
        conn

      true ->
        case decision(character, combat, attacker, mate_room) do
          {:noop} ->
            conn

          {:already} ->
            conn

          {:fight, _id} ->
            engage(conn, character, attacker)

          {:move, room, _id} ->
            engage_after_move(conn, character, attacker, room)

          _ ->
            conn
        end
    end
  end

  @doc "助战结束（被 `combat/tick` 在无敌人且已在助战时调用）：回 startroom"
  def finish(conn) do
    character = conn.character
    combat = character.meta.combat
    startroom = spawn_room_id(character)

    combat = Combat.set_helping(combat, false)
    character = put_combat(character, combat)
    conn = put_character(conn, character)

    cond do
      startroom == nil or character.room_id == startroom ->
        conn

      true ->
        conn
        |> Teleport.teleport(startroom)
    end
  end

  # ---- 决策 ----

  defp decision(character, combat, attacker, mate_room) do
    Coagent.start_help(%{
      in_target_room?: character.room_id == mate_room,
      already_killing?: Combat.enemy?(combat, attacker.id),
      helping?: Combat.helping?(combat),
      fighting?: Combat.fighting?(combat),
      target_room: mate_room,
      target_id: attacker.id,
      living?: alive?(character)
    })
  end

  # ---- 参战 ----

  defp engage(conn, character, attacker) do
    conn
    |> mark_helping(character)
    |> start_fight(attacker)
    |> send_enemy_start(attacker)
  end

  defp engage_after_move(conn, character, attacker, room) do
    conn
    |> mark_helping(character)
    |> Teleport.teleport(room)
    |> start_fight(attacker)
    |> send_enemy_start(attacker)
  end

  defp mark_helping(conn, character) do
    combat = character.meta.combat |> Combat.set_helping(true)
    conn |> put_character(put_combat(character, combat))
  end

  # 自己把攻击方加入敌人列表并启动心跳。
  # 注意 combat/start 由角色自身控制器处理（非房间），必须直接投递 self()，
  # 不能走 conn |> event（那会路由到房间路由器）。
  defp start_fight(conn, attacker) do
    character = latest(conn)

    send(self(), %Event{
      from_pid: self(),
      topic: "combat/start",
      data: %{enemy: ref(attacker), initiator_id: character.id}
    })

    conn
  end

  # 让攻击方把我加入敌人列表（直接投递对方）
  defp send_enemy_start(conn, attacker) do
    character = latest(conn)

    if Process.alive?(attacker.pid) do
      send(attacker.pid, %Event{
        from_pid: self(),
        topic: "combat/start",
        data: %{enemy: ref(character), initiator_id: character.id}
      })
    end

    conn
  end

  # ---- 工具 ----

  defp latest(conn), do: conn.private.update_character || conn.character

  defp spawn_room_id(%{meta: %{combat_config: %{spawn_room_id: id}}}), do: id
  defp spawn_room_id(_), do: nil

  defp alive?(%{meta: %{combat: %Combat{dead: dead}}}), do: not dead
  defp alive?(_), do: true

  defp dead?(%{meta: %{combat: %Combat{dead: true}}}), do: true
  defp dead?(_), do: false

  defp ref(character),
    do: %{
      id: character.id,
      pid: character.pid,
      name: character.name,
      room_id: character.room_id
    }

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}
end

defmodule Kantele.Character.MoveEvent do
  use Kalevala.Character.Event

  require Logger

  alias Kantele.Character.CommandView
  alias Kantele.Character.MoveView

  def commit(conn, %{data: event}) do
    character = conn.character
    old_room = character.room_id

    conn = notify_enemies_left(conn, character)
    notify_followers(character, event.exit_name)
    notify_team(character, event.exit_name)

    # 先更新自身 room_id 再排队移动事件：
    # 移动事件携带的角色快照（Private.character）必须带新房间号，
    # 否则目标房间存档的玩家 room_id 是旧值，战斗同房校验会误判
    character = %{character | room_id: event.to}

    conn =
      conn
      |> put_character(character)
      |> move(:from, old_room, MoveView, "leave", %{})
      |> move(:to, event.to, MoveView, "enter", %{})
      |> unsubscribe("rooms:#{old_room}", [], &unsubscribe_error/2)
      |> subscribe("rooms:#{event.to}", [], &subscribe_error/2)
      |> event("room/look")

    conn
  end

  # 触发跟随者沿同一出口移动（Batch 5 follow）：只通知存活进程
  defp notify_followers(character, exit_name) when is_binary(exit_name) and exit_name != "" do
    followers = Map.get(character.meta, :followers, [])

    Enum.each(followers, fn follower ->
      if is_map(follower) && Process.alive?(follower.pid) do
        send(follower.pid, %Kalevala.Event{
          from_pid: self(),
          topic: "follow/move",
          data: %{exit_name: exit_name}
        })
      end
    end)
  end

  defp notify_followers(_character, _exit_name), do: :ok

  # 触发队伍成员沿同一出口移动（Batch 6 team）：队长移动时带队员
  defp notify_team(character, exit_name) when is_binary(exit_name) and exit_name != "" do
    case Map.get(character.meta, :team) do
      %{members: members} ->
        Enum.each(members, fn member ->
          if is_map(member) && member.pid != character.pid && Process.alive?(member.pid) do
            send(member.pid, %Kalevala.Event{
              from_pid: self(),
              topic: "follow/move",
              data: %{exit_name: exit_name}
            })
          end
        end)

      _ ->
        :ok
    end
  end

  defp notify_team(_character, _exit_name), do: :ok

  # 离开房间时通知自己的敌人移除自己（对应 LPC clean_up_enemy 的环境校验）
  defp notify_enemies_left(conn, character) do
    combat = character.meta.combat

    case combat do
      %Kantele.Character.Combat{} ->
        Enum.each(combat.enemies, fn enemy ->
          if Process.alive?(enemy.pid) do
            send(enemy.pid, %Kalevala.Event{
              from_pid: self(),
              topic: "combat/enemy-left",
              data: %{id: character.id}
            })
          end
        end)

      _ ->
        :ok
    end

    conn
  end

  def abort(conn, %{data: event}) do
    conn
    |> render(MoveView, "fail", event)
    |> prompt(CommandView, "prompt")
  end

  def notice(conn, %{data: event}) do
    conn = room_item_init(conn, event)
    greet(conn, event)

    conn
    |> assign(:character, event.character)
    |> assign(:direction, event.direction)
    |> assign(:reason, event.reason)
    |> render(MoveView, "notice")
    |> prompt(CommandView, "prompt")
  end

  # 房间内**物品**的 `init()`（LPC 玩家进屋时房间里每个对象收到 init）。
  # 只对「自己」那条 notice 生效：`conn.character` 是 `player:*` 即为进入者。
  defp room_item_init(conn, %{direction: :to}) do
    case conn.character do
      %{id: "player:" <> _, room_id: room_id} ->
        Kantele.World.RoomItemInit.on_enter(conn, room_id)

      _ ->
        conn
    end
  end

  defp room_item_init(conn, _event), do: conn

  # NPC 欢迎（对应 LPC greeting()）：有玩家进入房间且在欢迎台词，随机挑一句
  # 广播到房间。NPC 自己（player:*）或没有 greetings 的 NPC 直接跳过。
  # 台词自身已含 NPC 名与称谓（LPC say 的 "$N" 即说话者），直接原样广播。
  defp greet(conn, %{character: character, direction: :to}) do
    npc = conn.character

    cond do
      is_nil(npc) || String.starts_with?(npc.id, "player:") ->
        :ok

      true ->
        # 先查逐 NPC 条件问候派发（LPC greeting() 忠实移植）；未注册回退静态池。
        case Kantele.World.NpcGreeting.greet(npc, character) do
          {:say, lines, action} when is_list(lines) ->
            # 台词按序全广播后，再执行收尾动作（如老鸨骂完把太监踢出门）
            Enum.each(lines, &emit_greeting(npc, character, &1))
            run_greeting_action(npc, character, action)

          {:say, lines} when is_list(lines) and lines != [] ->
            # handler 返回的台词按序全广播（对应 LPC 多次 command("say")）
            Enum.each(lines, &emit_greeting(npc, character, &1))

          :skip ->
            :ok

          _ ->
            case Map.get(npc.meta, :greetings) do
              lines when is_list(lines) and lines != [] ->
                # 静态池是「择一」台词池（LPC switch random），随机取一句
                say_greeting(npc, character, Enum.random(lines))

              _ ->
                :ok
            end
        end
    end
  end

  defp greet(_conn, _event), do: :ok

  defp say_greeting(npc, character, line) do
    room = %Kantele.World.Room{id: npc.room_id}
    Kantele.World.Room.tell_room(room, render_greeting(line, npc, character.name))
  end

  # handler 台词条目：二进制 = `command("say ...")`；
  # `{:vision, text}` / `{:vision, text, room_id, except}` = LPC `message("vision", ...)`
  # （`room_id`/`except` 可为 nil：默认 NPC 所在房间、不排除任何人）。
  defp emit_greeting(npc, character, {:vision, text, room_id, except}) when is_binary(text) do
    room = %Kantele.World.Room{id: room_id || npc.room_id}
    Kantele.World.Room.tell_room(room, render_greeting(text, npc, character.name), except)
  end

  defp emit_greeting(npc, character, {:vision, text}) when is_binary(text) do
    emit_greeting(npc, character, {:vision, text, nil, nil})
  end

  defp emit_greeting(npc, character, text) when is_binary(text) do
    say_greeting(npc, character, text)
  end

  # 台词播完后的收尾动作（对应 LPC greeting() 里 say 之后的副作用）。
  # `{:teleport, room_id}` = `me->move(<room>)`：NPC 进程没有玩家 conn，
  # 只能发事件让玩家进程自己走 `Teleport.teleport/2`。
  defp run_greeting_action(npc, character, {:teleport, room_id}) when is_binary(room_id) do
    # 两个 pid 都要是活的才投得动（房间快照里的 NPC/玩家理论上都有 pid，
    # 单测里可能没挂，宁可什么都不做也不要 send/2 抛 ArgumentError）
    if is_pid(Map.get(character, :pid)) and is_pid(Map.get(npc, :pid)) do
      send(character.pid, %Kalevala.Event{
        from_pid: npc.pid,
        topic: "character/teleport",
        data: %{room_id: room_id}
      })
    end

    :ok
  end

  defp run_greeting_action(_npc, _character, _action), do: :ok

  defp render_greeting(line, npc, player_name) do
    line
    |> String.replace("{npc}", npc.name)
    |> String.replace("{name}", player_name)
    |> String.replace("{respect}", "客官")
    |> String.replace("{rude}", "")
    |> String.replace("{expr}", "")
  end

  def unsubscribe_error(conn, error) do
    Logger.error("Tried to unsubscribe from the old room and failed - #{inspect(error)}")

    conn
  end

  def subscribe_error(conn, error) do
    Logger.error("Tried to subscribe to the new room and failed - #{inspect(error)}")

    conn
  end
end

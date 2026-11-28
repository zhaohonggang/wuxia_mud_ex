defmodule Kantele.World.InquiryHandlers.EmeiLiBack do
  @moduledoc """
  李明霞「上山/back」带人传送 + 回程定时器——LPC `kungfu/class/emei/li.c` 的 `ask_back/0`。

  门控顺序（严格按 LPC）：
    1. NPC 必须在 startroom（否则拒绝，文案「别什么都问我，我不知道！」）
    2. 玩家必须同门（否则拒绝，文案「你不是长脚了吗？难道上山还要我来抬你？」）
    3. 玩家 age < 18（否则拒绝，文案「我说你呀，年纪这么大了还要我带你上山么？」）

  成功流程：
    1. NPC say：好吧，看在同门的分上，我就带你上山吧。
    2. 房间广播：$N 拉着 $n 的手向山顶上走去。
    3. 玩家私发：你觉得省力多了，毫不费劲的就上了金顶。
    4. 玩家瞬移到 金顶。
    5. 房间广播（旧房间）：{npc}一手拉着{name}快步的向山上走去，一会儿就不见影子了。
    6. NPC 跟随瞬移到 金顶。
    7. 玩家 start_busy(1)。
    8. 5 秒后 NPC 自动返回 startroom（LPC call_out("back_to_startroom", 5)）：
       - 房间广播（金顶）：$N 头也不回的急急忙忙走了。
       - NPC 移动到 startroom。
       - 房间广播（startroom）：$N 大步流星的赶了过来。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "emei_li_back"
        target_room = "emei:jinding"   # 传送目标房间（金顶）
        startroom = "emei:huayanding"   # NPC 必须在此房间；5 秒后返回此处
        family = "峨嵋派"               # 限门派
        family_deny = "你不是长脚了吗？难道上山还要我来抬你？"
        room_deny = "别什么都问我，我不知道！"
        age_deny = "我说你呀，年纪这么大了还要我带你上山么？"
      say_text = "好吧，看在同门的分上，我就带你上山吧。"
      vision_a = "$N拉着$n的手向山顶上走去。\n\n"
      tell_text = "你觉得省力多了，毫不费劲的就上了金顶。\n"
      vision_b = "{npc}一手拉着{name}快步的向山上走去，一会儿就不见影子了。\n"
      back_delay = 5                  # NPC 返回延迟（秒，LPC call_out 第二参数）
      back_vision_a = "$N 头也不回的急急忙忙走了。\n"
      back_vision_b = "$N 大步流星的赶了过来。\n"
      }

  与 LPC 差异：
  - LPC `start_busy()` 无参数，ex 传 1 轮。
  - NPC 移动复用 `CallOut.schedule`（即 `Process.send_after` + `npc/call-out` 事件），
    回调在 NPC 进程上执行 `Teleport.teleport/2`。
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Family
  alias Kantele.Character.Teleport
  alias Kantele.World.NpcActions.CallOut
  alias Kantele.World.NpcActions.Helpers

  @busy_rounds 1

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      Map.get(data, :asker_id) != character.id ->
        conn

      true ->
        run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    cond do
      # LPC: if (find_object(query("startroom")) != environment()) return "别什么都问我，我不知道！"
      room_denied?(data, config) ->
        reply(conn, Helpers.respect(character) <> room_deny_text(config))

      # LPC: if (me->query("family/family_name") != query("family/family_name")) return "..."
      family_denied?(character, config) ->
        reply(conn, Helpers.respect(character) <> family_deny_text(config))

      # LPC: if (me->query("age") >= 18) return "..."
      age_denied?(character, config) ->
        reply(conn, Helpers.respect(character) <> age_deny_text(config))

      true ->
        do_back(conn, character, config, data)
    end
  end

  defp do_back(conn, character, config, data) do
    npc_name = Map.get(config, "vision_name") || Map.get(data, :npc_name) || "对方"
    room_id = Map.get(data, :npc_room_id)
    target_room = Map.get(config, "target_room")
    player_name = character.name || "你"

    conn =
      cond do
        not is_binary(room_id) or not is_binary(target_room) ->
          conn

        true ->
          # LPC: command("say 好吧，看在同门的分上，我就带你上山吧。")
          conn
          |> Helpers.say(room_id, npc_name, say_text(config))
          # LPC: message_vision("$N 拉着 $n 的手向山顶上走去。\n\n", this_object(), me)
          |> broadcast_room(room_id, vision_a_text(config), npc_name, player_name)
          # LPC: tell_object(me, "你觉得省力多了，毫不费劲的就上了金顶。\n")
          |> tell_player(tell_text(config))
          # LPC: me->move("/d/emei/jinding")
          |> Teleport.teleport(target_room)
          # LPC: message("vision", name() + "一手拉着" + me->name() + "...", environment())
          |> broadcast_room(room_id, vision_b_text(config), npc_name, player_name)
          # LPC: move("/d/emei/jinding") — NPC 随行
          |> teleport_npc_now(data, target_room)
          # LPC: me->start_busy()
          |> start_busy_player
      end

    # LPC: call_out("back_to_startroom", 5)
    schedule_npc_return(data, config)

    conn
  end

  # ---- 门控 ----

  defp room_denied?(%{npc_room_id: room_id}, config) do
    case Map.get(config, "startroom") do
      start when is_binary(start) and start != "" ->
        room_id != start
      _ ->
        true
    end
  end

  defp room_denied?(_data, _config), do: true

  defp family_denied?(character, config) do
    case Map.get(config, "family") do
      family when is_binary(family) and family != "" ->
        Helpers.family_name(character) != family
      _ ->
        false
    end
  end

  defp age_denied?(character, _config) do
    player_age(character) >= 18
  end

  # ---- 房间广播（$N/$n → 真实姓名，所有人同文）----

  defp broadcast_room(conn, room_id, template, npc_name, player_name)
       when is_binary(template) do
    text =
      template
      |> String.replace("$N", npc_name)
      |> String.replace("$n", player_name)
      |> String.replace("{npc}", npc_name)
      |> String.replace("{name}", player_name)
      |> ensure_newline()

    Helpers.broadcast(conn, room_id, text)
  end

  defp broadcast_room(conn, _room_id, _template, _npc_name, _player_name), do: conn

  # ---- 玩家私发（tell_object 等价）----

  defp tell_player(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp tell_player(conn, _text), do: conn

  # ---- NPC 即时随行（CallOut.schedule delay=0，在 NPC 进程执行 Teleport.teleport）----

  defp teleport_npc_now(conn, data, target_room) when is_binary(target_room) do
    case Map.get(data, :npc_pid) do
      pid when is_pid(pid) ->
        CallOut.schedule(%{pid: pid}, __MODULE__, :npc_teleport, 0, [target_room])
        conn

      _ ->
        conn
    end
  end

  defp teleport_npc_now(conn, _data, _target_room), do: conn

  # ---- 玩家忙乱（start_busy 等价）----

  defp start_busy_player(conn) do
    latest = conn.private.update_character || conn.character
    combat = Map.get(latest.meta, :combat) || Combat.new()
    combat = Combat.start_busy(combat, @busy_rounds)
    meta = %{latest.meta | combat: combat}
    put_character(conn, %{latest | meta: meta})
  end

  # ---- NPC 延迟返回（CallOut.schedule delay=back_delay）----

  defp schedule_npc_return(data, config) do
    case Map.get(data, :npc_pid) do
      pid when is_pid(pid) ->
        case Map.get(config, "startroom") do
          startroom when is_binary(startroom) ->
            delay = Map.get(config, "back_delay", 5)
            CallOut.schedule(
              %{pid: pid},
              __MODULE__,
              :npc_return,
              delay,
              [startroom, back_vision_a_text(config), back_vision_b_text(config)]
            )
          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  # ---- NPC 进程回调（由 CallOut.schedule 投递，在 NPC conn 上运行）----

  defp npc_teleport(conn, room_id) when is_binary(room_id) do
    Teleport.teleport(conn, room_id)
  end

  defp npc_teleport(conn, _room_id), do: conn

  defp npc_return(conn, startroom, vision1, vision2) when is_binary(startroom) do
    npc = conn.character
    room_id = npc.room_id

    # LPC: if (find_object(startroom) == environment()) return;
    if room_id == startroom do
      conn
    else
      # LPC: message_vision("$N 头也不回的急急忙忙走了。\n", this_object())
      conn =
        conn
        |> broadcast_room_npc(room_id, vision1, npc.name)
        # LPC: move(startroom)
        |> Teleport.teleport(startroom)
        # LPC: message_vision("$N 大步流星的赶了过来。\n", this_object())
        |> broadcast_room_npc(startroom, vision2, npc.name)

      conn
    end
  end

  defp npc_return(conn, _startroom, _vision1, _vision2), do: conn

  defp broadcast_room_npc(conn, room_id, template, npc_name)
       when is_binary(template) do
    text =
      template
      |> String.replace("$N", npc_name)
      |> String.replace("{npc}", npc_name)
      |> ensure_newline()

    Helpers.broadcast(conn, room_id, text)
  end

  defp broadcast_room_npc(conn, _room_id, _template, _npc_name), do: conn

  # ---- 文案 ----

  defp say_text(config), do: Map.get(config, "say_text") || "好吧，看在同门的分上，我就带你上山吧。"

  defp vision_a_text(config),
    do: Map.get(config, "vision_a") || "$N拉着$n的手向山顶上走去。\n\n"

  defp tell_text(config),
    do: Map.get(config, "tell_text") || "你觉得省力多了，毫不费劲的就上了金顶。\n"

  defp vision_b_text(config),
    do: Map.get(config, "vision_b") || "{npc}一手拉着{name}快步的向山上走去，一会儿就不见影子了。\n"

  defp back_vision_a_text(config),
    do: Map.get(config, "back_vision_a") || "$N 头也不回的急急忙忙走了。\n"

  defp back_vision_b_text(config),
    do: Map.get(config, "back_vision_b") || "$N 大步流星的赶了过来。\n"

  defp room_deny_text(config),
    do: Map.get(config, "room_deny") || "别什么都问我，我不知道！"

  defp family_deny_text(config),
    do: Map.get(config, "family_deny") || "你不是长脚了吗？难道上山还要我来抬你？"

  defp age_deny_text(config),
    do: Map.get(config, "age_deny") || "我说你呀，年纪这么大了还要我带你上山么？"

  # ---- helpers ----

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp player_age(character) do
    case Map.get(character.attributes || %{}, "age") do
      age when is_integer(age) -> age
      _ ->
        case Map.get(Map.get(character.meta, :env) || %{}, :age) do
          age when is_integer(age) -> age
          _ -> 0
        end
    end
  end

  defp ensure_newline(text) do
    if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
  end

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn
end

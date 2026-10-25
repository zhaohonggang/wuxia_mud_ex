defmodule Kantele.World.InquiryHandlers.Hostile do
  @moduledoc """
  问询触怒 NPC → 房间放话 + 直接开打（`kind = "hostile"`）。

  LPC 源（两处，均为**无条件触发**、无门控）：

  - `d/fuzhou/npc/linzhennan.c` `ask_pixie()`（问「辟邪剑法」）：
    `message_vision(HIR "林震南大怒道：你竟敢窥视我林家辟邪剑谱！今日就让你见识
    见识！" NOR, environment(), this_object())` 后 `kill_ob(this_player())`。
  - `d/emei/npc/songqingshu.c` `ask_for_zhou()`（问「周芷若」）：
    `command("heng")` → `command("say " + ob->query("name") + "你是什么东西？敢直呼
    芷若的名字？")` → `kill_ob(this_player())`；`return -1`（不再有 tell_object 回话）。

  ## UCL 配置（`inquiries` 的 map 值）

      value = {
        kind = "hostile"
        message = "{name}你是什么东西？敢直呼芷若的名字？"  # 必填；{name} → 问者名
        say = true            # 可选：以「<NPC名>说道：」前缀广播（LPC command("say")）
        emote = "哼了一声"     # 可选：放话前先播一句 NPC 动作（LPC command("heng")）
      }

  `{name}` 是转换器对 LPC `$n` / `ob->query("name")` 的占位（见
  `lpc_converter.ex` 的 `$n` → `{name}` 归一），在本 kind 一律替换为问者名字。

  ## 与 LPC 的差异

  - `command("heng")` 引擎无 NPC command 通道，按 `emote` 配置广播一句
    「<NPC名>哼了一声。」替代（不配置则整句省略，如林震南原文就没有）。
  - `kill_ob` 走 `NpcAttack.kill_ob/2` 的事件契约：问者进程与 NPC 进程各收
    `combat/start`（`type: "kill"`），由心跳战斗接管。目标取**问者本人**
    （LPC `this_player()`），与问询键无关。
  - LPC `return -1`：不私发任何文本，问者只从房间广播看到放话。
  """

  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.NpcActions.NpcAttack

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "message")) -> conn
      Map.get(data, :asker_id) != character.id -> conn
      true -> provoke(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC 顺序：emote → 放话 → kill_ob
  defp provoke(conn, character, config, data) do
    conn = emote(conn, config, data)
    conn = speak(conn, character, config, data)
    attack(conn, character, data)
  end

  # LPC `command("heng")`：NPC 自顾自的一个动作（房间广播）。
  defp emote(conn, config, data) do
    case {Map.get(config, "emote"), room_id(data)} do
      {emote, room_id} when is_binary(emote) and is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "对方"
        Helpers.broadcast(conn, room_id, "#{npc_name}#{emote}。\n")

      _ ->
        conn
    end
  end

  # LPC `message_vision` / `command("say ...")`：问者名替换 `{name}` 占位后房间广播。
  defp speak(conn, character, config, data) do
    message = String.replace(config["message"], "{name}", character.name || "你")

    case {Map.get(config, "say"), room_id(data)} do
      {say, room_id} when is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "对方"

        if say in [true, "true"] do
          Helpers.say(conn, room_id, npc_name, message)
        else
          Helpers.broadcast(conn, room_id, message <> "\n")
        end

      _ ->
        conn
    end
  end

  # LPC `kill_ob(this_player())`：问者与 NPC 互相开战。
  #
  # 快照按 `NpcAttack.kill_ob/2` 的契约就地构造：NPC 四项取自 inquiry 回执
  # （`npc_pid` 即 NPC 进程 `self()`）；问者 pid 取 `self()` —— 本 handler 运行在
  # 问者进程内（`NpcScriptEvent.inquiry_result` 的调用点），无需查房间快照。
  defp attack(conn, character, data) do
    npc = %{
      id: Map.get(data, :npc_id),
      pid: Map.get(data, :npc_pid),
      name: Map.get(data, :npc_name),
      room_id: Map.get(data, :npc_room_id)
    }

    player = %{
      id: character.id,
      pid: self(),
      name: character.name,
      room_id: character.room_id
    }

    NpcAttack.kill_ob(npc, player)

    conn
  end

  defp room_id(data) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) -> room_id
      _ -> nil
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

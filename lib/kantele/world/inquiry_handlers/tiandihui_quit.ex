defmodule Kantele.World.InquiryHandlers.TiandihuiQuit do
  @moduledoc """
  天地会退会（`kind = "tiandihui_quit"`），逐字移植
  `kungfu/class/yunlong/chen.c:95-113` 的 `ask_tuihui()`。

  LPC 原文只有两条分支：

  1. `party/party_name != "天地会"` →
     `message_vision("陈近南笑了笑，对$N说道：你还没加入我天地会呢，退什么退？\\n", ob)`
  2. 已是天地会 → `command("look <id>")` → `command("sigh ")` →
     `command("say 反清复明，就要坚贞志士，你去吧! ")` →
     `delete("party") / delete("rank") / delete("level")`

  `tiandihui.h do_join` 首行即 `notify_fail`，永不可达，故本模块**不实现入会**：
  这里的 party 身份只能由其它已实现的入口或 wizard 写入 `meta.env`。
  `command("look ...")` / `sigh` 在本端口按既有 NPC emote 惯例落为房间广播。

  UCL 配置：

      party_name = "天地会"
      not_member_msg = "陈近南笑了笑，对{name}说道：你还没加入我天地会呢，退什么退？"
      look_msg = "{npc}看了看{name}。"
      sigh_msg = "{npc}叹了口气。"
      quit_say = "反清复明，就要坚贞志士，你去吧! "
  """

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Party
  alias Kantele.Character.Records
  alias Kantele.World.NpcActions.Helpers

  @default_not_member "陈近南笑了笑，对{name}说道：你还没加入我天地会呢，退什么退？\n"
  @default_look "{npc}看了看{name}。"
  @default_sigh "{npc}叹了口气。"
  @default_say "反清复明，就要坚贞志士，你去吧! "

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) == character.id do
      if Party.name(character) == Map.get(config, "party_name", "天地会") do
        quit_tiandihui(conn, character, config, data)
      else
        broadcast(
          conn,
          config,
          data,
          "not_member_msg",
          @default_not_member,
          false
        )
      end
    else
      conn
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC 顺序：look → sigh → say → delete(party/rank/level)。
  defp quit_tiandihui(conn, character, config, data) do
    conn =
      conn
      |> broadcast(config, data, "look_msg", @default_look, true)
      |> broadcast(config, data, "sigh_msg", @default_sigh, true)

    conn = say(conn, config, data)

    character = Party.quit(character)
    Records.save(character)
    put_character(conn, character)
  end

  defp broadcast(conn, config, data, key, default, append_newline?) do
    room_id = Map.get(data, :npc_room_id) || character_of(conn).room_id

    if is_binary(room_id) do
      template = Map.get(config, key) || default
      text = render(template, data, character_of(conn))
      Helpers.broadcast(conn, room_id, ensure_newline(text, append_newline?))
    else
      conn
    end
  end

  defp say(conn, config, data) do
    room_id = Map.get(data, :npc_room_id) || character_of(conn).room_id
    npc_name = Map.get(data, :npc_name) || "陈近南"
    text = Map.get(config, "quit_say") || @default_say

    if is_binary(room_id) and is_binary(text) do
      Helpers.say(conn, room_id, npc_name, text)
    else
      conn
    end
  end

  defp render(template, data, character) do
    asker = Map.get(data, :asker_name) || character.name
    npc = Map.get(data, :npc_name) || "陈近南"

    template
    |> String.replace("{name}", to_string(asker || ""))
    |> String.replace("{npc}", to_string(npc || ""))
  end

  defp ensure_newline(text, true) do
    if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
  end

  defp ensure_newline(text, false), do: text

  defp character_of(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp character_of(%{character: character}), do: character

  defp current(conn) do
    case conn do
      %{private: %{update_character: character}} when not is_nil(character) -> character
      %{character: character} -> character
    end
  end
end

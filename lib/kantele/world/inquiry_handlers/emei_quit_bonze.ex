defmodule Kantele.World.InquiryHandlers.EmeiQuitBonze do
  @moduledoc """
  灭绝师太「还俗」问询（`kind = "emei_quit_bonze"`）—— LPC
  `kungfu/class/emei/miejue.c` `ask_for_quit/0`。

  LPC 门控（严格按源码顺序）：
    1. `family/family_name != "峨嵋派"` → 「你是什么人？跑到这里来捣乱？\n」
    2. `class != "bonze"` → 「阿弥陀佛！你本是俗家人，何谈还俗？\n」
    3. 通过 → `me->set_temp("pending/quit_bonze", 1)` +
       `command("heng")`（NPC 房间发言）+
       return 「你好好的给我安心修炼，以后降妖除魔，别天天满脑子不正经。\n」

  端口映射：
    - `query("family/family_name")` → `meta.family[:name]`
    - `query("class")` → `meta.family[:class]`
    - `set_temp("pending/quit_bonze", 1)` → `meta.temp[:pending_quit_bonze] = true`
    - `command("heng")` → 由 UCL 的 `npc_say` 经房间频道广播（文案 "哼"）
    - `return <text>` → 玩家侧 text 渲染

  UCL 配置（灭绝师太 inquiries 中的「还俗」）:

      { key = "还俗" value = {
        kind = "emei_quit_bonze"
        npc_say = "哼"
      } }

  与剃度（emei_tonsure）的对应：
    - 剃度：family 门 → 已出家门 → 性别门 → pending/join_bonze
    - 还俗：family 门 → 未出家门 → pending/quit_bonze（无性别门，LPC 源码无 gender 检查）
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family

  @family "峨嵋派"
  @family_deny "你是什么人？跑到这里来捣乱？"
  @not_bonze_deny "阿弥陀佛！你本是俗家人，何谈还俗？"
  @success "你好好的给我安心修炼，以后降妖除魔，别天天满脑子不正经。"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = conn.character

    cond do
      family_name(character) != @family ->
        tell(conn, @family_deny)

      not_bonze?(character) ->
        tell(conn, @not_bonze_deny)

      true ->
        conn
        |> set_pending(character)
        |> broadcast_npc_say(config, data)
        |> tell(@success)
    end
  end

  def run(conn, _config, _data), do: conn

  defp family_name(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) ->
        Family.name(family) || Map.get(family, "family_name")

      _ ->
        nil
    end
  end

  # LPC query("class") != "bonze"：未出家方可还俗。
  defp not_bonze?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Map.get(family, :class) != "bonze"
      _ -> true
    end
  end

  defp set_pending(conn, character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_quit_bonze, true))
    Kalevala.Character.Conn.put_character(conn, %{character | meta: meta})
  end

  defp broadcast_npc_say(conn, config, data) do
    case {Map.get(config, "npc_say"), Map.get(data, :npc_room_id), Map.get(data, :npc_name)} do
      {say, room_id, npc_name}
      when is_binary(say) and byte_size(say) > 0 and is_binary(room_id) and is_binary(npc_name) ->
        Kantele.World.NpcActions.Helpers.say(conn, room_id, npc_name, say)

      _ ->
        conn
    end
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text <> "\n"})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end
end

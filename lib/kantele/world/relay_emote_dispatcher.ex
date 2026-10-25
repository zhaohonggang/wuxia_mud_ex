defmodule Kantele.World.RelayEmoteDispatcher do
  @moduledoc """
  P5-8 #8 后半触发层：把「社交动词 + 目标 NPC」路由到
  `Kantele.World.NpcActions.RelayEmote`。

  LPC 里 `relay_emote` 由社交命令层在玩家把社交动词指向某 NPC 时调用
  （`cmds` 社交系统不在本端口语料内）。本分发器在命令流里插入于
  `ItemActionDispatcher` 之后、`Commands.call` 之前：

  1. 从输入取出 verb + 目标（trailing 第一段）。
  2. 若 verb ∈ @social_verbs 且目标非空 → 在房间内按「名/别名」解析目标 NPC。
  3. 目标 NPC 在 `RelayEmote.config/1` 有登记 → 先广播玩家社交动作 vision，
     再调 `RelayEmote.run/3`，返回 `{:handled, conn}`。
  4. 否则 `:not_handled`，放行全局命令（对未移植的社交动词零影响）。

  ## 安全性（P7）

  仅当「动词是社交动词 ∧ 目标解析到登记 NPC」才拦截。其它输入（含 `beg`
  对玩家、其它动词）一律 `:not_handled`，不影响 `BegCommand` 等既有命令。
  """
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.NpcActions.RelayEmote
  alias Kantele.World.Room

  @social_verbs MapSet.new(["kick", "hug", "kiss", "mo", "18mo", "nocloth", "beg"])

  # 玩家做社交动词时，房间内看到的「玩家动作」文案（NPC 回应前的铺垫）
  @verb_player_action %{
    "kick" => "踢了一脚",
    "hug" => "紧紧抱住",
    "kiss" => "亲了一下",
    "mo" => "摸了摸",
    "18mo" => "动手动脚",
    "nocloth" => "上下其手",
    "beg" => "乞讨起来"
  }

  @doc """
  分发。返回 `{:handled, conn}` 或 `:not_handled`。

  `chars_fun` 可注入（默认查房间进程 `Room.npc_characters_by_id/1`），便于单测。
  """
  def dispatch(conn, data, chars_fun \\ &room_characters/1) do
    case resolve(conn, data, chars_fun) do
      {:handled, npc, verb} ->
        conn = broadcast_player_action(conn, npc, verb)
        {:handled, RelayEmote.run(conn, npc, verb)}

      :not_handled ->
        :not_handled
    end
  end

  defp resolve(conn, data, chars_fun) do
    text = String.trim(to_string(data))
    [verb | rest] = String.split(text, ~r/\s+/, parts: 2)
    target = case rest do [t] -> String.trim(t); _ -> "" end

    if MapSet.member?(@social_verbs, verb) and target != "" do
      npc = find_target(conn, target, chars_fun)

      if npc && RelayEmote.config(npc.name) do
        {:handled, npc, verb}
      else
        :not_handled
      end
    else
      :not_handled
    end
  end

  defp find_target(conn, target, chars_fun) do
    Enum.find(chars_fun.(conn), fn c ->
      c.name == target or target in List.wrap(c.aliases)
    end)
  end

  defp room_characters(conn) do
    case conn.character do
      %{room_id: room_id} when is_binary(room_id) -> Room.npc_characters_by_id(room_id)
      _ -> []
    end
  end

  defp broadcast_player_action(conn, npc, verb) do
    action = Map.get(@verb_player_action, verb, verb)
    room_id = conn.character.room_id
    Helpers.broadcast(conn, room_id, "$N对着#{npc.name}#{action}。")
  end
end

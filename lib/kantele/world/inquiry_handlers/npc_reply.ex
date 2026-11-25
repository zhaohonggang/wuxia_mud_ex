defmodule Kantele.World.InquiryHandlers.NpcReply do
  @moduledoc """
  少林道果「修木人/修理/木人」服务型问询（`kind = "npc_reply"`）。

  LPC 源 `dao-guo.c` `ask_me/0`（逐条忠实，不简化）：

  1. `family == "少林派"` 检查 → 非少林弟子时返回拒绝文案；
  2. 通过后设 `pending/daoguo_repair = 1`，NPC 随玩家前往 木人 进行修理；
  3. 渲染「我们走罢！」文案给玩家。

  ## 端口映射

  - `query("family")` → `meta.family.name`（见 Family.name/1）
  - `set_temp("pending/daoguo_repair", 1)` → `meta.temp[:pending_daoguo_repair] = true`
  - `return <text>` → 玩家侧 text 渲染（LPC inquiry 回调返回字符串给 tell_object）

  ## UCL 配置（道果 inquiries）

      inquiries = [
        { key = "修木人" value = { kind = "npc_reply" } },
        { key = "修理" value = { kind = "npc_reply" } },
        { key = "木人" value = { kind = "npc_reply" } }
      ]
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family

  def run(conn, _config, data) when is_map(data) do
    character = conn.character

    cond do
      not shaolin_disciple?(character) ->
        tell(conn, "你与本派素无来往，不知此话从何谈起？\n")

      true ->
        set_pending_and_tell(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC family == "少林派"：family name 存于 meta.family.name
  defp shaolin_disciple?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Family.name(family) == "少林派"
      _ -> false
    end
  end

  defp set_pending_and_tell(conn, character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_daoguo_repair, true))
    character = %{character | meta: meta}
    conn = Kalevala.Character.Conn.put_character(conn, character)

    tell(conn, "我们走罢！\n")
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end
end

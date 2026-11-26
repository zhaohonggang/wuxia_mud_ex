defmodule Kantele.World.InquiryHandlers.XueshanTonsure do
  @moduledoc """
  大轮寺剃度问询（`kind = "xueshan_tonsure"`）—— 葛伦布/嘉木活佛/拉章活佛/萨木活佛
  「剃度/出家」。

  LPC 源 `kungfu/class/xueshan/tobebonze.h` `ask_for_join/0`（逐条忠实，不简化）：

  1. `class == "bonze"` → 「你已经是出家人了，还跟我罗嗦些什么？」
  2. `gender != "男性"` → 「我们大轮寺历来只收男徒，你还是走吧。」
  3. 通过 → 设 `pending/join_bonze = 1`，「甚好，甚好！你若真心皈依我佛，请跪下(kneel)受戒。」

  ## 端口映射

  - `query("class")` → `meta.family[:class]`（LPC class 存在 family map，见 family_event.ex）
  - `query("gender")` → `meta.env[:gender]`（见 records.ex:33-35）
  - `set_temp("pending/join_bonze", 1)` → `meta.temp[:pending_join_bonze] = true`
  - `return <text>` → 玩家侧 text 渲染（LPC inquiry 回调返回字符串给 tell_object）

  ## UCL 配置（四名 NPC 的 inquiries）

      inquiries = [
        { key = "出家" value = { kind = "xueshan_tonsure" } },
        { key = "剃度" value = { kind = "xueshan_tonsure" } }
      ]
  """

  alias Kantele.Character.CommandView

  def run(conn, _config, data) when is_map(data) do
    character = conn.character

    cond do
      bonze?(character) ->
        tell(conn, "你已经是出家人了，还跟我罗嗦些什么？\n")

      gender(character) != "男性" ->
        tell(conn, "我们大轮寺历来只收男徒，你还是走吧。\n")

      true ->
        set_pending_and_tell(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC query("class")=="bonze"：class 存于 meta.family.class
  defp bonze?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Map.get(family, :class) == "bonze"
      _ -> false
    end
  end

  defp gender(character) do
    env = Map.get(character.meta || %{}, :env) || %{}
    Map.get(env, :gender) || Map.get(env, "gender") || "男性"
  end

  defp set_pending_and_tell(conn, character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_join_bonze, true))
    character = %{character | meta: meta}
    conn = Kalevala.Character.Conn.put_character(conn, character)

    tell(conn, "甚好，甚好！你若真心皈依我佛，请跪下(kneel)受戒。\n")
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end
end

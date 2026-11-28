defmodule Kantele.World.InquiryHandlers.EmeiTonsure do
  @moduledoc """
  峨嵋派剃度问询（`kind = "emei_tonsure"`）—— 九名师太「出家/剃度」。

  LPC 源 `kungfu/class/emei/tobebonze.h` `ask_for_join/0`（逐条忠实，不简化）：

  1. `family/family_name != "峨嵋派"` → 「施主与我峨嵋派尚无渊源，贫尼不敢给你剃度。」
  2. `class == "bonze"` → 「阿弥陀佛！出家人不打诳语。你已经不是俗家人了。」
  3. `gender != "女性"` → 「阿弥陀佛！善哉！善哉！施主若真心皈依我佛，可去少林寺受戒。」
  4. 通过 → `command("say ...")` 由 NPC 向房间说出跪拜提示，再设
     `pending/join_bonze = 1`，并私发「记住，既然出了家，就一心向佛，不能还俗。」

  ## 端口映射

  - `query("family/family_name")` → `meta.family[:name]`（框架统一映射）
  - `query("class")` → `meta.family[:class]`
  - `query("gender")` → `meta.env[:gender]`
  - `set_temp("pending/join_bonze", 1)` → `meta.temp[:pending_join_bonze] = true`
  - `command("say <text>")` → 由 UCL 的 `npc_say` 经房间频道广播；未配置则不广播，
    与既有多处 LPC `command("say")` 端口一致。
  - `return <text>` → 玩家侧 text 渲染

  ## UCL 配置（九名 NPC 的 inquiries）

      inquiries = [
        { key = "出家" value = { kind = "emei_tonsure" npc_say = "阿弥陀佛！..." } },
        { key = "剃度" value = { kind = "emei_tonsure" npc_say = "阿弥陀佛！..." } }
      ]

  后续 `kneel` 见 `Kantele.World.NpcActions.EmeiKneel`。
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.World.NpcActions.Helpers

  @family "峨嵋派"
  @family_deny "施主与我峨嵋派尚无渊源，贫尼不敢给你剃度。"
  @bonze_deny "阿弥陀佛！出家人不打诳语。你已经不是俗家人了。"
  @gender_deny "阿弥陀佛！善哉！善哉！施主若真心皈依我佛，可去少林寺受戒。"
  @success "记住，既然出了家，就一心向佛，不能还俗。"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = conn.character

    cond do
      family_name(character) != @family ->
        tell(conn, @family_deny)

      bonze?(character) ->
        tell(conn, @bonze_deny)

      gender(character) != "女性" ->
        tell(conn, @gender_deny)

      true ->
        conn
        |> set_pending(character)
        |> broadcast_npc_say(config, data)
        |> tell(@success)
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC query("family/family_name")：框架 family map 用 :name。
  defp family_name(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) ->
        Family.name(family) || Map.get(family, "family_name")

      _ ->
        nil
    end
  end

  # LPC query("class")=="bonze"：class 存于 meta.family.class。
  defp bonze?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Map.get(family, :class) == "bonze"
      _ -> false
    end
  end

  defp gender(character) do
    env = Map.get(character.meta || %{}, :env) || %{}
    Map.get(env, :gender) || Map.get(env, "gender")
  end

  defp set_pending(conn, character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_join_bonze, true))
    Kalevala.Character.Conn.put_character(conn, %{character | meta: meta})
  end

  # LPC `command("say ...")`：只在成功分支广播，且保留与私发返回值不同的原文。
  defp broadcast_npc_say(conn, config, data) do
    case {Map.get(config, "npc_say"), Map.get(data, :npc_room_id), Map.get(data, :npc_name)} do
      {say, room_id, npc_name}
      when is_binary(say) and byte_size(say) > 0 and is_binary(room_id) and is_binary(npc_name) ->
        Helpers.say(conn, room_id, npc_name, say)

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

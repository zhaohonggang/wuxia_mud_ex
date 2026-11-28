defmodule Kantele.World.InquiryHandlers.MessageSort do
  @moduledoc """
  LPC `message_sort(msg, me, you)` 的数据驱动 equivalent（GAP #803）。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "message_sort"
        text = "$N对$n说：“……”"
      }

  LPC `message_sort` 对三个接收者分别渲染（见 `adm/single/simul_efun/message.c:58-92`，
  `gender_self/1` 恒为 "你"）：

  - 听话人 `you`（本例为问询玩家）：`$N` → NPC 名，`$n` → "你"；
  - 说话人 `me`（岛主）：`$N` → "你"，`$n` → 玩家名（NPC 无显示端，故省略）；
  - 同房间其他人：`$N` → NPC 名，`$n` → 玩家名；
  - `$p` 与 `$n` 同理（提问者 "你" / 旁观者玩家名），供只写 `$p` 的
    LPC 模板使用（如 `d/city/npc/smith.c:81` 的 `ask_back()`）。

  本模块先给问询玩家发私有 vision（`"你"` 版），再向房间广播旁观者版并用
  `:exclude_actor` 排除问询玩家，避免他收到两份不同渲染。两种占位写法都支持：
  LPC 原样 `$N`/`$n`（clone_lib 为 object_only，校验器豁免）与转换器归一化的
  `{npc}`/`{name}`。

  未配置 `text`、非问询者本人、无房间 id 时不广播；后一种情况仍保留私有文案，
  对应 LPC `environment(me)` 为空时只发给 `you` 的分支。
  """

  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      case template(config) do
        nil ->
          conn

        text ->
          npc_name = Map.get(data, :npc_name) || "某人"
          asker_name = Map.get(data, :asker_name) || character.name
          conn = Helpers.render(conn, render(text, npc_name, "你", "你"))

          case Map.get(data, :npc_room_id) do
            room_id when is_binary(room_id) and byte_size(room_id) > 0 ->
              Helpers.broadcast(
                conn,
                room_id,
                render(text, npc_name, asker_name, asker_name),
                exclude_actor: true
              )

            _ ->
              conn
          end
      end
    end
  end

  def run(conn, _config, _data), do: conn

  defp template(config) do
    text = Map.get(config, "text") || Map.get(config, "msg") || Map.get(config, "message")

    if is_binary(text) and byte_size(text) > 0, do: text, else: nil
  end

  # LPC message_sort 的 $p：提问者视角 = gender_self(you)（恒为「你」），
  # 旁观者视角 = you->name()。与 $n 的差别在于提问者视角两者都是「你」，
  # 但 LPC 原文可能只写 $p（如 d/city/npc/smith.c ask_back），故必须单独替换。
  defp render(text, npc_name, target_name, target_pronoun) do
    text
    |> String.replace("$N", npc_name)
    |> String.replace("$n", target_name)
    |> String.replace("$p", target_pronoun)
    |> String.replace("{npc}", npc_name)
    |> String.replace("{name}", target_name)
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

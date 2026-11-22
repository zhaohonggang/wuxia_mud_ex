defmodule Kantele.World.InquiryHandlers.BornFamilyReply do
  @moduledoc """
  天龙寺枯荣 `ask_me()` 的出身家族双分支问询（`kind = "born_family_reply"`）。

  LPC 三键（六脉神剑 / 六脉神剑谱 / 六脉神剑剑谱）共用同一闭包：

      if (me->query("born_family") != "段氏皇族")
          message_vision("$N冷笑一声道：" + RANK_D->query_respect(me) +
                         "打听我们天龙寺镇寺之宝干什么？\\n", this_object());
      else
          message_vision("$N淡然对$n道：你虽然是皇族之人，但是也不"
                         "得染指六脉神剑剑谱。\\n", this_object(), me);
      end

  UCL 配置：

      value = {
        kind = "born_family_reply"
        required_born_family = "段氏皇族"
        msg_match = "$N淡然对$n道：..."   # 出身命中
        msg_other = "$N冷笑一声道：{respect}..."  # 其余出身
      }

  `$N` = NPC 名，`$n` = 提问者名，`{respect}` = LPC `RANK_D->query_respect`
  （引擎现统一「大侠」，见 `NpcActions.Helpers.respect/1`）。替换后再走房间广播，
  避免 Task #822 的裸 `$n` 泄漏。
  """

  alias Kantele.World.NpcActions.Helpers

  @doc """
  把 LPC `message_vision` 占位符替换为最终文案。公开供测试与复用。
  """
  def render_text(text, npc_name, asker_name) when is_binary(text) do
    text
    |> String.replace("$N", to_string(npc_name || ""))
    |> String.replace("$n", to_string(asker_name || ""))
    |> String.replace("{respect}", Helpers.respect(nil))
  end

  def render_text(_text, _npc_name, _asker_name), do: ""

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) == character.id do
      text = choose_text(config, character)

      if is_binary(text) and byte_size(text) > 0 do
        rendered =
          render_text(
            text,
            Map.get(data, :npc_name),
            Map.get(data, :asker_name) || character.name
          )

        case Map.get(data, :npc_room_id) do
          room_id when is_binary(room_id) -> Helpers.broadcast(conn, room_id, rendered)
          _ -> conn
        end
      else
        conn
      end
    else
      conn
    end
  end

  def run(conn, _config, _data), do: conn

  defp choose_text(config, character) do
    required = Map.get(config, "required_born_family")

    if is_binary(required) and byte_size(required) > 0 and born_family(character) == required do
      Map.get(config, "msg_match")
    else
      Map.get(config, "msg_other")
    end
  end

  # LPC `me->query("born_family")`：setup_controller 落 meta.env，
  # 老数据 / 家族对象里也可能带 :born_family，两者都读。
  defp born_family(%{meta: meta}) do
    env = Map.get(meta, :env) || %{}

    env_value =
      Map.get(env, :born_family) || Map.get(env, "born_family") ||
        case Map.get(meta, :family) do
          family when is_map(family) ->
            Map.get(family, :born_family) || Map.get(family, "born_family")

          _ ->
            nil
        end

    if is_binary(env_value), do: env_value, else: to_string(env_value || "")
  end

  defp born_family(_character), do: ""

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

defmodule Kantele.World.InquiryHandlers.TeleportService do
  @moduledoc """
  LPC `ask_me` 类「传送服务」问询（`kind = "teleport_service"`）。

  镜像 `kungfu/class/hu/pingsi.c` 的 `ask_me`：校验家族 + 当前房间（NPC 所在房间
  必须是配置的 startroom），符合条件则把玩家瞬移到目标房间，并广播马车文案。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "teleport_service"
        target_room = "beijing:majiu"   # 传送目标房间 id（zone:room_key）
        startroom = "guanwai:xiaoyuan"  # NPC 必须在此房间（玩家必须在此对话）
        family = "关外胡家"             # 限门派；缺省不限
        vision_name = "平四"            # 房间广播里的 NPC 短名
        success = "马车已备，请上车。"   # 传送成功私发给玩家
        family_deny = "你自己没长腿么？" # 非本门时的返回值（自动加敬称）
        room_deny = "我这里还有事，你就自己走回去吧。"  # 不在 startroom 时的返回值
        vision = "平四朝远方一招手，顿时几个参客赶着马车驶了过来..."  # 房间广播
      }

  门控顺序：家族 → 房间 → 传送。

  与 LPC 差异：
  - LPC 检查 NPC 环境是否为 startroom；Elixir 侧等价检查 `data.npc_room_id`，
    因玩家与 NPC 必须同房才能对话，二者等价。
  - 传送复用 `Teleport.teleport/2`（两段 Movement 事件 + 房间频道重订阅）。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.Character.Teleport

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
      family_denied?(character, config) ->
        reply(conn, Helpers.respect(character) <> family_deny_text(config))

      room_denied?(data, config) ->
        reply(conn, Helpers.respect(character) <> room_deny_text(config))

      true ->
        do_teleport(conn, character, config, data)
    end
  end

  defp do_teleport(conn, _character, config, data) do
    target_room = Map.get(config, "target_room")
    room_id = Map.get(data, :npc_room_id)
    npc_name = Map.get(config, "vision_name") || Map.get(data, :npc_name) || "对方"

    conn =
      cond do
        not is_binary(target_room) ->
          conn

        not is_binary(room_id) ->
          conn

        true ->
          vision = vision_text(config)
          conn
          |> Helpers.broadcast(room_id, "#{npc_name}#{vision}\n")
          |> Teleport.teleport(target_room)
      end

    reply(conn, success_text(config))
  end

  defp family_denied?(character, config) do
    case Map.get(config, "family") do
      family when is_binary(family) and family != "" ->
        family_name(character) != family
      _ ->
        false
    end
  end

  defp family_name(%{meta: %{family: family}}) when is_map(family), do: Family.name(family)
  defp family_name(_character), do: nil

  defp room_denied?(%{npc_room_id: room_id}, config) do
    case Map.get(config, "startroom") do
      start when is_binary(start) and start != "" ->
        room_id != start
      _ ->
        false
    end
  end

  defp room_denied?(_data, _config), do: false

  defp vision_text(config), do: Map.get(config, "vision") || "招手示意。"

  defp family_deny_text(config),
    do: Map.get(config, "family_deny") || "与本派素无来往，不知此话从何谈起？"

  defp room_deny_text(config),
    do: Map.get(config, "room_deny") || "我这里还有事，你就自己走回去吧。"

  defp success_text(config),
    do: Map.get(config, "success") || "已为你安排。"

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

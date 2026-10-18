defmodule Kantele.World.NpcActionDispatcher do
  @moduledoc """
  NPC 私有动词分发路由(P5-1c-2）。

  在 `Kantele.Character.CommandController.recv` 的全局命令入口**之后、房间
  分发器之后**插入本分发器：
  提取玩家输入的动词 → 查当前房间内哪个 NPC 的 `meta.init.add_actions`
  包含该动词 → 经 `NpcActionHandlers.lookup/2`(按房间级 registry）解析
  handler `{module, function}`。

  - 命中且已注册(P5-1c-3 移植了 handler）→ 执行 handler，拦截全局命令。
  - 未命中 / handler 未移植(`{:unimplemented, _}`）→ 返回 `:not_handled`，
    由调用方继续走 `Kantele.Character.Commands.call`(全局命令）。

  ## 安全性(P7）

  当前 `NpcActionHandlers.@registry` 仅包含已移植的 `yun`，所有其它 NPC
  动词都走 `:not_handled`，**对全局命令零行为影响**。P5-1c-3 每注册一个
  handler，对应 NPC 的动作才被激活。

  ## 优先级

  LPC 语义中 NPC `add_action` 动词优先于同名全局命令。本分发器插在
  `Commands.call` 之前，即实现该优先级；重名 verb 的激活须谨慎。

  ## 关注点：稳定 NPC 键

  registry 按 `room_id`(UCL 房间 id，重启不变）而不是
  `Character.generate_id()`(重启变动）索引。同一房间内若多个 NPC 注册了
  同一动词，取第一个命中者。
  """
  alias Kantele.World.NpcActionHandlers

  @doc """
  分发玩家输入。返回 `{:handled, conn}` 或 `:not_handled`。

  `lookup_fun` 可注入(默认 `NpcActionHandlers.lookup/2`），便于单测用假
  注册表验证正向路径而不污染真实注册表。
  """
  def dispatch(conn, text, lookup_fun \\ &NpcActionHandlers.lookup/2) do
    case resolve(conn, text, lookup_fun) do
      {:handled, {module, function}, params} ->
        case apply(module, function, [conn, params]) do
          # LPC `return 0`：handler 声明本次不处理，放行全局命令
          :not_handled -> :not_handled
          conn -> {:handled, conn}
        end

      :not_handled ->
        :not_handled
    end
  end

  @doc """
  纯决策：是否由 NPC 私有动词拦截。返回 `{:handled, {mod, fun}, params}`
  或 `:not_handled`。
  """
  def resolve(conn, text, lookup_fun \\ &NpcActionHandlers.lookup/2) do
    verb = extract_verb(text)
    room_id = room_id_of(conn)

    case priority_action(conn, verb, room_id, lookup_fun) do
      {:handled, {module, function}, npc} ->
        {:handled, {module, function}, build_params(verb, text, conn, npc)}

      :not_handled ->
        :not_handled
    end
  end

  defp extract_verb(text) when is_binary(text) do
    case String.trim(text) |> String.split(~r/\s+/, parts: 2) do
      [verb | _] when verb != "" -> verb
      _ -> nil
    end
  end

  defp extract_verb(_), do: nil

  defp priority_action(_conn, nil, _room_id, _lookup_fun), do: :not_handled

  defp priority_action(conn, verb, room_id, lookup_fun) when is_binary(verb) do
    case find_npc(conn, verb) do
      nil ->
        :not_handled

      npc ->
        case lookup_fun.(room_id, verb) do
          {:ok, {module, function}} -> {:handled, {module, function}, npc}
          {:unimplemented, _name} -> :not_handled
        end
    end
  end

  # 取当前房间内的 NPC 角色列表。
  #
  # 快速路径：`conn.private.room`(测试可直接注入一个带 `:characters` 的
  # Room 结构体）。引擎不保证 `conn.private.room` 恒包含 characters，
  # 缺失时返回 []，即安全降级为全局命令放行(P7）。
  defp npc_characters(conn) do
    case Map.get(conn, :private) do
      %{room: room} when is_map(room) ->
        Map.get(room, :characters, [])

      _ ->
        []
    end
  end

  # 在房间内找第一个 `meta.init.add_actions` 包含该 verb 的 NPC。
  # 只有 NPC 才会携带 `init.add_actions`，故该条件天然区分 NPC 与玩家。
  defp find_npc(conn, verb) do
    Enum.find(npc_characters(conn), fn character ->
      verb in npc_add_actions(character)
    end)
  end

  defp npc_add_actions(character) do
    case Map.get(character.meta, :init) do
      %{add_actions: actions} when is_list(actions) -> actions
      _ -> []
    end
  end

  defp room_id_of(conn) do
    case Map.get(conn, :character) do
      %{room_id: rid} when is_binary(rid) -> rid
      _ -> nil
    end
  end

  defp build_params(verb, text, conn, npc) do
    trailing =
      case String.trim(text) |> String.split(~r/\s+/, parts: 2) do
        [_verb, rest] -> String.trim(rest)
        _ -> ""
      end

    room_id = room_id_of(conn)

    %{verb: verb, trailing: trailing, room_id: room_id, npc: npc}
  end
end

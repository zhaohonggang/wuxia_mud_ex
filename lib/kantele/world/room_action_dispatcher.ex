defmodule Kantele.World.RoomAction do
  @moduledoc """
  房间 `add_action` handler 行为契约（P5-1b）。

  每个从 LPC `do_*` 函数移植来的房间动词处理函数实现本行为。handler 接收
  `conn` 与 `params`，必须返回更新后的 `conn`：

      defmodule Kantele.World.RoomActions.Move do
        use Kantele.World.RoomAction
        def run(conn, %{verb: verb, trailing: trailing, room_id: room_id}) do
          # ... 处理逻辑 ...
          conn
        end
      end

  `params` 字段：
  - `:verb` — 玩家输入的动词（与 UCL `actions` 键原样匹配，大小写敏感）
  - `:trailing` — 动词之后的剩余文本（已 trim，无则为 `""`）；对应 LPC `do_*` 的 `arg`
  - `:room_id` — 当前房间 id（`conn.character.room_id`）；handler 需改动房间
    （如 LPC `set("exits/down", ...)`）时用它向房间进程发事件

  ## 返回 `:not_handled`（LPC `return 0`）

  handler 可以返回 `:not_handled`，等价于 LPC `do_*` 里的 `return 0` ——
  「本次输入我不处理，交回命令解析」。分发器会把它当作未命中放行全局命令
  （如 `d/xiakedao/xiaowu.c` 的 `do_move` 在 `arg != "bed"` 时 `return 0`）。
  """
  @callback run(conn :: Kalevala.Character.Conn.t(), params :: map()) ::
              Kalevala.Character.Conn.t() | :not_handled

  defmacro __using__(_opts) do
    quote do
      @behaviour Kantele.World.RoomAction
    end
  end
end

defmodule Kantele.World.RoomActionDispatcher do
  @moduledoc """
  对象级 verb 分发路由（P5-1b-2）。

  在 `Kantele.Character.CommandController.recv` 的全局命令入口**之前**插入本分发器：
  提取玩家输入的动词 → 查当前房间的 `actions`（`Room.resolve_action/2`）→ 经
  `RoomActionHandlers.lookup/2`（房间级）解析 handler 名到 Elixir `{module, function}`。

  - 命中且已注册（P5-1b-3 移植了 handler）→ 执行 handler，拦截全局命令。
  - 未命中 / handler 未移植（`{:unimplemented, _}`）→ 返回 `:not_handled`，
    由调用方继续走 `Kantele.Character.Commands.call`（全局命令）。

  ## 安全性（P7）
  当前 `RoomActionHandlers.@registry` 为空，所有 verb 都走 `:not_handled`，
  **对全局命令零行为影响**。P5-1b-3 每注册一个 handler，对应房间的动作才被激活。

  ## 优先级
  LPC 语义中房间 `add_action` 动词**优先于**同名全局命令（如房间里的 "move"
  覆盖全局 `MoveCommand`）。本分发器即实现该优先级；重名 verb 的激活须谨慎
  （look/say/get/open/close 等核心命令，handler 未完整移植前不应注册）。
  """
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers

  @doc """
  分发玩家输入。返回 `{:handled, conn}` 或 `:not_handled`。

  `lookup_fun` 可注入（默认 `RoomActionHandlers.lookup/2`），便于单测用假注册表
  验证正向路径而不污染真实（当前仅 1 个房间 1 个 handler 的）注册表。
  """
  def dispatch(conn, text, lookup_fun \\ &RoomActionHandlers.lookup/2) do
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
  纯决策：是否由房间 verb 拦截。返回 `{:handled, {mod, fun}, params}` 或 `:not_handled`。
  """
  def resolve(conn, text, lookup_fun \\ &RoomActionHandlers.lookup/2) do
    verb = extract_verb(text)
    actions = get_room_actions(conn)
    room_id = room_id_of(conn)

    case priority_action(actions, verb, room_id, lookup_fun) do
      {:handled, {module, function}} ->
        {:handled, {module, function}, build_params(verb, text, conn)}

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

  # 取当前房间的 actions 映射（P5-1b-2 运行时修正）：
  # 引擎不把房间塞进 conn.private.room（恒为 nil），故优先用 Room.actions_by_id
  # 直接查房间进程；单测可把结构体放进 conn.private.room 走快速路径。
  defp get_room_actions(conn) do
    case Map.get(conn, :room) || conn.private.room do
      %Room{actions: actions} -> actions
      _ -> fetch_actions_by_character(conn)
    end
  end

  defp fetch_actions_by_character(conn) do
    case Map.get(conn, :character) do
      %{room_id: room_id} when is_binary(room_id) -> Room.actions_by_id(room_id)
      _ -> %{}
    end
  end

  defp priority_action(_actions, nil, _room_id, _lookup_fun), do: :not_handled

  defp priority_action(actions, verb, room_id, lookup_fun) when is_binary(verb) do
    case Room.resolve_action(%Room{actions: actions}, verb) do
      {:ok, handler} ->
        case lookup_fun.(room_id, handler) do
          {:ok, {module, function}} -> {:handled, {module, function}}
          {:unimplemented, _name} -> :not_handled
        end

      {:error, :no_such_action} ->
        :not_handled
    end
  end

  defp room_id_of(conn) do
    case Map.get(conn, :character) do
      %{room_id: rid} when is_binary(rid) -> rid
      _ -> nil
    end
  end

  defp build_params(verb, text, conn) do
    trailing =
      case String.trim(text) |> String.split(~r/\s+/, parts: 2) do
        [_verb, rest] -> String.trim(rest)
        _ -> ""
      end

    room_id =
      case Map.get(conn, :character) do
        %{room_id: rid} when is_binary(rid) -> rid
        _ -> nil
      end

    %{verb: verb, trailing: trailing, room_id: room_id}
  end
end

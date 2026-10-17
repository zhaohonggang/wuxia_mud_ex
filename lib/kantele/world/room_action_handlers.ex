defmodule Kantele.World.RoomActionHandlers do
  @moduledoc """
  房间 `add_action` handler 注册表（P5-1b）。

  LPC 房间通过 `add_action("verb", "handler")` 注册自定义动词，handler 是 LPC
  函数名（如 `do_move`、`do_climb`）。回填（P5-1a2）已把 304 个房间的
  `verb → handler` 写入 UCL `Room.actions`。本模块负责把 **handler 名** 解析为
  可执行的 Elixir `{module, function}`，由 P5-1b-2 的对象级分发路由调用。

  ## 移植策略
  handler 共 130 种（见 `scripts/tmp/p5a2_room_actions_survey.json`），呈长尾分布：
  前 15 种（do_move/do_climb/do_jump/do_push/do_enter/...）覆盖绝大多数调用。逐个把
  LPC 函数体移植为 Elixir 命令模块，注册到下方 `@registry` 即可。未注册的 handler
  经 `lookup/1` 返回 `{:unimplemented, name}`，分发路由据此给出友好提示而非崩溃。

  ## 注册示例
      @registry %{
        "do_move" => {Kantele.World.RoomActions.Move, :run}
      }
  """
  # 已移植的 handler → {module, function}。初始为空，随 P5-1b-3 逐个填充。
  @registry %{}

  @doc """
  解析 handler 名到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, handler_name}`。
  """
  def lookup(handler_name) when is_binary(handler_name) do
    case Map.get(@registry, handler_name) do
      nil -> {:unimplemented, handler_name}
      {module, function} -> {:ok, {module, function}}
    end
  end

  def lookup(handler_name), do: {:unimplemented, handler_name}

  @doc "该 handler 是否已有 Elixir 实现（已注册）。"
  def registered?(handler_name), do: Map.has_key?(@registry, handler_name)

  @doc "当前已注册（已移植）的 handler 名列表，用于覆盖度统计。"
  def registered_names(), do: Map.keys(@registry)
end

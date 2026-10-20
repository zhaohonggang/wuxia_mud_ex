defmodule Kantele.World.ItemDescHandlers do
  @moduledoc """
  动态 `item_desc` handler 注册表（P5-4d）。

  LPC `set("item_desc", ([ "bi" : (: look_bi :) ]))` 的闭包值在 UCL 中表示为
  `bi = { kind = "..." ... }`。`kind` 到 Elixir `{module, function}` 的解析在
  本模块。handler 接收 `(context, requester, params)`，返回更新后的房间
  `context`：

      def run(context, requester, %{keyword: keyword, config: config}) do
        # ...
        render(context, requester.pid, CommandView, "text", %{text: text})
      end

  ## 安全降级（P7）
  未注册的 kind 由 `lookup/2` 返回 `{:unimplemented, kind}`，房间回落到
  「这里没有这个东西。」，与未回填的 `item_desc` 行为一致。
  """

  @registry %{
    "hengyang:inzhushendong" => %{
      "gated_text" => {Kantele.World.ItemDescHandlers.GatedText, :run}
    }
  }

  @doc """
  解析 `(room_id, kind)` 到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, kind}`。
  """
  def lookup(room_id, kind) when is_binary(room_id) and is_binary(kind) do
    with room_map when is_map(room_map) <- Map.get(@registry, room_id),
         {module, function} <- Map.get(room_map, kind) do
      {:ok, {module, function}}
    else
      _ -> {:unimplemented, kind}
    end
  end

  def lookup(_room_id, kind), do: {:unimplemented, kind}

  @doc "该房间的 kind 是否已有 Elixir 实现（已注册）。"
  def registered?(room_id, kind), do: match?({:ok, _}, lookup(room_id, kind))

  @doc "当前已注册的房间 id 列表，用于覆盖度统计。"
  def registered_rooms(), do: Map.keys(@registry)
end

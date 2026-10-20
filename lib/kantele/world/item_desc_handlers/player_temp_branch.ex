defmodule Kantele.World.ItemDescHandlers.PlayerTempBranch do
  @moduledoc """
  数据驱动动态 `item_desc`：玩家 temp 解锁后，再按房间 temp 分支（P5-4g）。

  LPC 常见形式：

      string look_liang()
      {
          object me = this_player();

          if (! me->query_temp("marks/辟1"))
              return "你要看什么？\\n";

          if (query("move"))
              return "一根楠木做的房梁，上面有崭新的刮痕……\\n";

          me->set_temp("marks/辟2", 1);
          return "一根楠木做的房梁，可惜年代太久……\\n";
      }

  UCL 示例：

      item_desc = {
       liang = {
        kind = "player_temp_branch"
        gate_temp = "marks/辟1"
        no_access = "你要看什么？"
        room_key = "move"
        shown = "一根楠木做的房梁，上面有崭新的刮痕……"
        hidden = "一根楠木做的房梁，可惜年代太久……"
        set_temp = "marks/辟2"
       }
      }

  `gate_temp` 未设置时返回 `no_access`；已设置后若当前房间 temp `room_key`
  为真返回 `shown`，否则返回 `hidden` 并可置 `set_temp`（仅角色进程落盘）。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  @default_text "这里没有这个东西。\n"
  @default_no_access "你要看什么？\n"

  def run(context, requester, %{config: config}) do
    cond do
      not temp_set?(requester, Map.get(config, "gate_temp")) ->
        render_text(context, requester, Map.get(config, "no_access") || @default_no_access)

      room_temp_set?(context, Map.get(config, "room_key")) ->
        render_text(
          context,
          requester,
          Map.get(config, "shown") || Map.get(config, "hidden") || @default_text
        )

      true ->
        context
        |> maybe_set_temp(requester, Map.get(config, "set_temp"))
        |> render_text(requester, Map.get(config, "hidden") || @default_text)
    end
  end

  defp render_text(context, requester, text) do
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp temp_set?(%{meta: %{temp: temp}}, key) when is_binary(key) do
    truthy?(Map.get(temp || %{}, key))
  end

  defp temp_set?(_requester, _key), do: false

  defp room_temp_set?(context, key) when is_binary(key) and key != "" do
    truthy?(Map.get(Map.get(context.data, :state, %{}) || %{}, key))
  end

  defp room_temp_set?(_context, _key), do: false

  defp truthy?(value), do: not (is_nil(value) or value == false or value == 0 or value == "")

  defp maybe_set_temp(context, requester, key) when is_binary(key) and key != "" do
    event(context, requester.pid, self(), "character/effects", %{
      effects: [{:set_temp, key, 1}]
    })
  end

  defp maybe_set_temp(context, _requester, _key), do: context

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end

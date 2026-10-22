defmodule Kantele.World.ItemDescHandlers.RoomTempTiers do
  @moduledoc """
  数据驱动动态 `item_desc`：按房间 temp 多个键的「首个命中」选择文本（P5-4l）。

  对应 LPC（hengyang:outzigai1 的 `look_bi`）：

      if (here->query_temp("marks/破"))
          return "石壁已经被打破了。\\n";
      if (here->query_temp("marks/推"))
          return "石门已经被推开了，却露出一个山洞来。\\n";
      return "这块石壁看起来很坚实……";

  UCL 示例：

      item_desc = {
       bi = {
        kind = "room_temp_tiers"
        tiers = [
         { key = "marks/破" text = "石壁已经被打破了。" }
         { key = "marks/推" text = "石门已经被推开了，却露出一个山洞来。" }
        ]
        default = "这块石壁看起来很坚实……"
       }
      }

  `tiers` 按声明顺序取第一个「房间 temp[key] 为真」的层级；都不命中时返回 `default`。
  房间 temp 取自当前房间进程 `context.data.state`（与 `RoomTempText` 一致 —— `look` 命令在
  房间进程内执行，直接读 `context.data` 避免 `:sys.get_state(self())` 死锁）。

  与 `room_state_tiers` 的区别：后者要求指定键「精确相等」（多键联合匹配），本 handler
  只判「首个存在的键」，适合 `marks/破` / `marks/推` 这类互斥标记位。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  @default_text "这里没有这个东西。\n"

  def run(context, requester, %{config: config}) do
    state = Map.get(context.data, :state, %{}) || %{}
    text = select(state, Map.get(config, "tiers"), Map.get(config, "default"))
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp select(_state, nil, default), do: default || @default_text
  defp select(_state, [], default), do: default || @default_text

  defp select(state, [%{} = tier | rest], default) do
    key = Map.get(tier, "key")

    if truthy?(Map.get(state, key)) do
      Map.get(tier, "text") || default || @default_text
    else
      select(state, rest, default)
    end
  end

  defp select(_state, _tiers, default), do: default || @default_text

  defp truthy?(value), do: not (is_nil(value) or value == false or value == 0 or value == "")

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end

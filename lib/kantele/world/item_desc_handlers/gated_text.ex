defmodule Kantele.World.ItemDescHandlers.GatedText do
  @moduledoc """
  数据驱动动态 `item_desc`：按角色 temp 标志选择隐藏/揭示文本（P5-4d）。

  UCL 示例：

      item_desc = {
       bi = {
        kind = "gated_text"
        gate_temp = "gua"
        hidden = "尘土已将其掩盖，不知道后面藏有什么。"
        shown = "只见山壁上刻有三副巨图。"
       }
      }

  对应 LPC：

      if (! me->query_temp("gua"))
        return "尘土已将其掩盖，不知道后面藏有什么。\\n";
      return "只见山壁上刻有三副巨图。\\n";

  `hidden` / `shown` 均按 UCL 单行字符串约定书写（换行折叠为空格），handler
  统一补一个结尾换行，与静态 `item_desc` 的渲染保持一致。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  @default_hidden "这里没有这个东西。\n"

  def run(context, requester, %{config: config}) do
    text =
      if temp_set?(requester, config["gate_temp"]) do
        Map.get(config, "shown") || Map.get(config, "hidden") || @default_hidden
      else
        Map.get(config, "hidden") || @default_hidden
      end

    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp temp_set?(%{meta: %{temp: temp}}, key) when is_binary(key) do
    case Map.get(temp || %{}, key) do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  defp temp_set?(_requester, _key), do: false

  defp ensure_newline(text) when is_binary(text) do
    String.trim_trailing(text) <> "\n"
  end

  defp ensure_newline(_text), do: @default_hidden
end

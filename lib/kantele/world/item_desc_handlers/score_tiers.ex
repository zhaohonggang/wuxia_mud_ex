defmodule Kantele.World.ItemDescHandlers.ScoreTiers do
  @moduledoc """
  数据驱动动态 `item_desc`：按角色 `score` 选择文本层级（P5-4e）。

  UCL 示例：

      item_desc = {
       jing = {
        kind = "score_tiers"
        tiers = [
         { min_score = 0 text = "..." },
         { min_score = 1000 text = "..." },
         { min_score = 5000 text = "..." }
        ]
       }
      }

  选择 `min_score <= score` 中最大的层级，对应 LPC 的多段 `if
  (me->query("score") < N) return ...`。`score` 读
  `requester.meta.stats.score`（缺失按 0）。

  可选 `set_temp = "marks/画1"`：命中该层时在角色进程置 `temp[key] = 1`
  （LPC `me->set_temp(...)` 的副作用）。房间进程只发
  `"character/effects"` 事件，由角色进程执行并落盘。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  @default_text "这里没有这个东西。\n"

  def run(context, requester, %{config: config}) do
    case select_tier(Map.get(config, "tiers"), score(requester)) do
      nil ->
        render(context, requester.pid, CommandView, "text", %{text: @default_text})

      tier ->
        context
        |> maybe_set_temp(requester, tier)
        |> render(requester.pid, CommandView, "text", %{
          text: ensure_newline(Map.get(tier, "text") || @default_text)
        })
    end
  end

  defp score(%{meta: %{stats: %{score: score}}}) when is_integer(score), do: score
  defp score(_requester), do: 0

  defp select_tier(tiers, score) when is_list(tiers) do
    tiers
    |> Enum.filter(fn
      %{} = tier ->
        is_integer(Map.get(tier, "min_score")) and Map.get(tier, "min_score") <= score

      _ ->
        false
    end)
    |> Enum.max_by(&Map.get(&1, "min_score"), fn -> nil end)
  end

  defp select_tier(_tiers, _score), do: nil

  defp maybe_set_temp(context, requester, tier) do
    case Map.get(tier, "set_temp") do
      key when is_binary(key) and key != "" ->
        event(context, requester.pid, self(), "character/effects", %{
          effects: [{:set_temp, key, 1}]
        })

      _ ->
        context
    end
  end

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end

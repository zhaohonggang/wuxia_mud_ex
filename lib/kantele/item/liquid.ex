defmodule Kantele.Item.Liquid do
  @moduledoc """
  液体（饮具）描述（对应 `feature/liquid.c` extra_long）

  按 remaining/max 与液体名生成容器内液体状况描述。`remaining == 0`
  或无 liquid 时返回 nil（LPC 返回 0）。
  """

  @doc "是否液体 (is_liquid)"
  def is_liquid?(_), do: true

  @doc "extra_long：按液量生成装满度描述"
  def extra_long(%{liquid: %{remaining: 0}}), do: nil
  def extra_long(%{liquid: %{remaining: remaining}} = meta) do
    max = Map.get(meta.liquid, :max) || Map.get(meta, :max_liquid)
    name = Map.get(meta.liquid, :name) || "液体"
    describe(remaining, max, name)
  end

  def extra_long(_), do: nil

  defp describe(amo, max, name) do
    cond do
      max == nil or max <= 0 -> "里面装了些#{name}。\n"
      amo == max -> "里面装满了#{name}。\n"
      amo >= div(max * 4, 5) -> "里面的#{name}被喝过少许，不过依然很满。\n"
      amo >= div(max * 2, 3) -> "里面装了七、八分满的#{name}。\n"
      amo >= div(max * 2, 5) -> "里面装了五、六分满的#{name}。\n"
      amo >= 1 -> "里面装了少许的#{name}。\n"
      true -> nil
    end
  end
end

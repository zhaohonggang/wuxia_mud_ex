defmodule Kantele.Item.Food do
  @moduledoc """
  食物（对应 `feature/food.c` 食物属性）

  - `is_food?/1`：判定是否为食物
  - 食物饱食度通过 `meta.food` 数据声明（整数），宿主在 eat 时调用
    `Kantele.Item.Effect.consume/3` 解读并作用于 vitals（气血）
  """

  @doc "是否食物 (is_food)"
  def is_food?(_), do: true
end

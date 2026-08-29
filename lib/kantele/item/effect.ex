defmodule Kantele.Item.Effect do
  @moduledoc """
  物品效果栈（对应 `feature/food.c` 与 `feature/liquid.c` 的 apply_effect 机制）

  食物/液体/药品等可叠加的效果函数列表（上限 12 个）。纯状态容器，
  宿主在吃/喝时 `do_effect/2` 依次执行。
  """

  @max_effects 12

  @doc "是否有效果 (is_food / is_liquid)"
  def has_effect?(effects) when effects != nil and effects != [], do: true
  def has_effect?(_), do: false

  @doc """
  追加效果 (LPC: apply_effect(f))；逻辑等价于把 f 追加到列表（上限 12，保序）
  """
  def apply_effect(nil, effect), do: [effect]
  def apply_effect(effects, nil), do: effects

  def apply_effect(effects, effect) when is_list(effects) do
    if length(effects) < @max_effects do
      effects ++ [effect]
    else
      effects
    end
  end

  def apply_effect(single, effect), do: [single, effect]

  @doc "清空效果 (LPC: clear_effect)"
  def clear_effect(_), do: []

  @doc "查询效果 (LPC: query_effect)"
  def query_effect(effects), do: effects

  @doc "执行全部效果 (LPC: do_effect(me))；以列表顺序依次执行"
  def do_effect(effects, ctx) when is_list(effects) do
    Enum.each(effects, &apply_fun(&1, ctx))
    :ok
  end

  def do_effect(effects, ctx), do: do_effect([effects], ctx)

  defp apply_fun(f, ctx) when is_function(f, 1), do: f.(ctx)
  defp apply_fun(f, _ctx) when is_function(f, 0), do: f.()
  defp apply_fun(_f, _ctx), do: nil
end

defmodule Kantele.Character.Encumbrance do
  @moduledoc """
  负重系统（对应 `feature/move.c` 的 weight/encumb/max_encumb）

  纯状态 reducer，state 形如 `%{weight:, encumb:, max_encumb:}`：

  - `weight(state) = weight + encumb`（"当前"总重，见 move() 校验）
  - `over_encumbranced?(state)` = encumb > max_encumb
  - `add_encumbrance(state, w)`：增加负重，穿过上限时调用 `on_over/1`
  - `set_weight(state, w)`：变更自身重量（外部环境负重由宿主按差值联动）
  - `move_out_weight(state)` / `move_in_weight(state)`：移出/移入时加减自身重
  """
  defstruct weight: 0, encumb: 0, max_encumb: 0

  @doc "当前总重（LPC weight()=weight+encumb）"
  def weight(%__MODULE__{weight: w, encumb: e}), do: w + e

  @doc "查询负重 (LPC query_encumbrance)"
  def query_encumbrance(%__MODULE__{encumb: e}), do: e

  @doc "最大负重 (LPC query_max_encumbrance)"
  def query_max_encumbrance(%__MODULE__{max_encumb: m}), do: m

  @doc "是否超载 (LPC over_encumbranced)"
  def over_encumbranced?(%__MODULE__{encumb: e, max_encumb: m}), do: e > m

  @doc "加负重 (LPC add_encumbrance)；跨上限回调 on_over（默认通知宿主）"
  def add_encumbrance(%__MODULE__{} = state, w, opts \\ %{}) when is_integer(w) do
    was_over = over_encumbranced?(state)
    encumb = state.encumb + w
    encumb = if encumb < 0, do: 0, else: encumb
    state = %{state | encumb: encumb}

    if not was_over and over_encumbranced?(state) do
      case Keyword.get(opts, :on_over) do
        fun when is_function(fun, 0) -> fun.()
        fun when is_function(fun, 1) -> fun.(state)
        _ -> :ok
      end
    end

    state
  end

  @doc "设置自身重量，返回（新state, 需差额联动）(LPC set_weight)"
  def set_weight(%__MODULE__{} = state, w) when is_integer(w) do
    if w != state.weight do
      {%{state | weight: w}, w - state.weight}
    else
      {state, 0}
    end
  end

  @doc "移出环境时减去自身当前总重（LPC env add_encumbrance(-weight()）)"
  def move_out_weight(%__MODULE__{} = state), do: -weight(state)

  @doc "移入环境时加上自身当前总重（LPC ob add_encumbrance(weight())）"
  def move_in_weight(%__MODULE__{} = state), do: weight(state)
end

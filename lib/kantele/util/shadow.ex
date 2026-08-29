defmodule Kantele.Util.Shadow do
  @moduledoc """
  影分身（对应 `feature/shadow.c`）

  LPC `shadow()` 提供对象行为拦截；Elixir 无同构，提供等价的状态机：
  - `do_shadow(state, target)`：记录被影目标
  - `remove_shadow(state, ob)`：仅解除对同一目标的影响（否则忽略）
  - `query_shadow_now/1`：当前被影目标

  纯容器，实际拦截由宿主代理分发。
  """

  @doc "do_shadow：shadowing = ob，返回 `{state, :shadowing}`"
  def do_shadow(state, target), do: {%{shadowing: target}, :shadowing}

  @doc "remove_shadow：ob != shadowing 时忽略；否则清空（LPC destruct 由宿主执行）"
  def remove_shadow(%{shadowing: target} = state, ob) do
    if ob != nil and ob != target do
      {state, :keep}
    else
      {%{shadowing: nil}, :removed}
    end
  end

  def remove_shadow(state, _ob), do: {state, :keep}

  @doc "query_shadow_now"
  def query_shadow_now(%{shadowing: target}), do: target
  def query_shadow_now(_), do: nil
end
defmodule Kantele.Character.Conditions do
  @moduledoc """
  通用持续状态（对应 `feature/condition.c` from ES2/XKX, by Doing for HELL）

  与 LPC 一致的通用 condition 周期机制：
  - `apply_condition(state, cnd, info)` → 写入 `%{conditions: %{cnd => info}, cond_applyer: ...}`
  - `query_condition(state, cnd)` / `clear_condition(state, cnd)`
  - `update_condition(state, daemon)` → 对每个 cnd 调用 daemon 的 `update_condition/2`；
    返回值含 `:continue` 则保留，否则清除（LPC CND_CONTINUE 标志）
  - `affect_by(state, cnd, para)` → 调 daemon 的 `do_effect/3`；有 `special_skill/piyi` 免疫

  `daemon` 为宿主注入的解析函数（`fn cnd -> {:ok, mod} | :error end`），
  模块需实现 optional `update_condition(state, info)` 与 `do_effect(state, cnd, para)`。

  纯函数：state 不可变，副作用在宿主。
  """

  @doc "query_condition：cnd=nil 返回全部；否则查单个（不存在返回 nil）"
  def query_condition(state, cnd \\ nil)

  def query_condition(%{conditions: conditions}, nil) when is_map(conditions), do: conditions
  def query_condition(_state, nil), do: nil

  def query_condition(%{conditions: conditions}, cnd) when is_map(conditions) do
    Map.get(conditions, cnd)
  end

  def query_condition(_state, _cnd), do: nil

  @doc "apply_condition：写入条件与施术者记录"
  def apply_condition(state, cnd, info, applyer \\ %{}) do
    state = state || %{}

    state =
      Map.update(state, :conditions, %{cnd => info}, fn conds ->
        if is_map(conds), do: Map.put(conds, cnd, info), else: %{cnd => info}
      end)

    if map_size(applyer) > 0 do
      Map.update(state, :cond_applyer, %{cnd => applyer}, fn apl ->
        if is_map(apl), do: Map.put(apl, cnd, applyer), else: %{cnd => applyer}
      end)
    else
      state
    end
  end

  @doc "clear_condition：cnd=nil 清空全部"
  def clear_condition(_state, nil) do
    %{}
  end

  def clear_condition(state, cnd) do
    state =
      update_in(state, [Access.key(:conditions, nil)], fn conds ->
        conds && if(is_map(conds), do: remove_then_nil(conds, cnd), else: nil)
      end)

    update_in(state, [Access.key(:cond_applyer, nil)], fn apl ->
      apl && if(is_map(apl), do: remove_then_nil(apl, cnd), else: nil)
    end)
  end

  @doc """
  update_condition：对每个条件迭代更新。

  daemon 解析函数返回:
  - `{:continue, new_info}` 或 `{:continue}` → 条件继续（更新 info）
  - `{:expire}` → 条件到期移除
  - `:error` → 无法解析，移除该条件
  """
  def update_condition(state, daemon) do
    conditions = Map.get(state, :conditions)
    applyer = Map.get(state, :cond_applyer)

    cond do
      not is_map(conditions) or map_size(conditions) == 0 ->
        {state |> Map.put(:conditions, nil) |> Map.put(:cond_applyer, nil), false}

      true ->
        {new_conditions, new_applyer, any_live?} =
          Enum.reduce(conditions, {%{}, intended_applyer(applyer), false}, fn {cnd, info},
                                                                               {acc, apl, live} ->
            case daemon.(cnd) do
              :error ->
                {acc, apl, live}

              {:ok, mod} ->
                result = update_one(mod, info)

                case result do
                  {:continue, new_info} ->
                    {Map.put(acc, cnd, new_info), apl, true}

                  {:continue} ->
                    {Map.put(acc, cnd, info), apl, true}

                  {:expire} ->
                    {Map.delete(acc, cnd), Map.delete(apl, cnd), live}
                end
            end
          end)

        state =
          state
          |> Map.put(:conditions, if(map_size(new_conditions) == 0, do: nil, else: new_conditions))
          |> Map.put(:cond_applyer, if(map_size(new_applyer) == 0, do: nil, else: new_applyer))

        {state, any_live?}
    end
  end

  @doc """
  affect_by：调用条件 do_effect；转世特殊技 `special_skill/piyi` 免疫。
  返回 `{:ok, result}` | `{:immune}` | `:error`。
  """
  def affect_by(state, daemon, cnd, para) do
    if get_in(state, [Access.key(:special_skill), :piyi]) do
      {:immune}
    else
      case daemon.(cnd) do
        :error -> :error
        {:ok, mod} -> {:ok, mod.do_effect(state, cnd, para || Map.get(state, :para))}
      end
    end
  end

  @doc "query_last_applyer（LPC: name/id 二组）"
  def query_last_applyer(state, cnd \\ nil)

  def query_last_applyer(state, nil), do: Map.get(state, :cond_applyer)
  def query_last_applyer(%{cond_applyer: apl}, cnd) when is_map(apl), do: Map.get(apl, cnd)
  def query_last_applyer(_state, _cnd), do: nil

  # ---- internal ----

  defp remove_then_nil(map, key) do
    m = Map.delete(map, key)
    if map_size(m) == 0, do: nil, else: m
  end

  defp intended_applyer(apl) when is_map(apl), do: apl
  defp intended_applyer(_), do: %{}

  defp update_one(mod, info) do
    cond do
      function_exported?(mod, :update_condition, 2) ->
        mod.update_condition(info)

      function_exported?(mod, :update_condition, 1) ->
        mod.update_condition(info)

      true ->
        {:expire}
    end
  end
end
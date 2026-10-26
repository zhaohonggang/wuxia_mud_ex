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

  alias Kantele.Character.SpecialSkills

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
          |> Map.put(
            :conditions,
            if(map_size(new_conditions) == 0, do: nil, else: new_conditions)
          )
          |> Map.put(:cond_applyer, if(map_size(new_applyer) == 0, do: nil, else: new_applyer))

        {state, any_live?}
    end
  end

  @doc """
  affect_by：调用条件 do_effect；转世特殊技 `special_skill/piyi` 免疫。

  免疫判定统一走 `SpecialSkills.immune?/2`（读 `attributes["special_skills"]`，
  与 `poison.ex`/`room.ex` 宿主形状一致）；返回 `{:ok, result}` | `{:immune}` | `:error`。
  """
  def affect_by(state, daemon, cnd, para) do
    attributes = Map.get(state, :attributes) || %{}

    if SpecialSkills.immune?(attributes, "piyi") do
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

  @doc """
  逐条件尝试驱散（对应 LPC `feature/condition.c dispel_condition` +
  `kungfu/skill/force/dispel.c` 的 `for` 循环）。

  daemon 可选导出 `dispel_condition/2`（名字照搬 LPC `feature/condition.c`
  的 `dispel_condition()`），签名 `dispel_condition(info, ctx)`，返回：

  - `:ok` / `{:ok, message}` — 驱散成功（该条件从 `conditions` 移除）
  - `{:fail, message}` — 驱散失败（保留该条件，LPC `still_ill = 1`）
  - `:skip` — 不处理（保留，不算失败）

  `ctx` 至少含 `%{force: integer, self?: boolean}`；驱散他人时调用方还可给
  `:target_name`。

  **与 LPC 的差异（有意）**：LPC `dispel_condition` 对**未实现该函数的
  condition 返回 0**（`case 0: continue` → 不驱散）；本引擎对未导出的 daemon
  默认 `:ok`（驱散），否则 `poison`/`nishui`/`duyan` 全部驱不掉、`排除异常`
  退化成摆设。需要抗性/门槛的 condition 自己导出 `dispel_condition/2` 即可。

  返回 `{remaining_conditions_or_nil, results}`，
  `results :: [{cnd, :ok | {:ok, msg} | {:fail, msg} | :skip}]`。
  """
  def dispel(conditions, ctx, daemon) when is_map(conditions) do
    {remaining, results} =
      Enum.reduce(conditions, {%{}, []}, fn {cnd, info}, {acc, res} ->
        case daemon.(cnd) do
          :error ->
            # 无法解析的条件不擅自删（保持既有 update_condition 的宽容语义）
            {Map.put(acc, cnd, info), [{cnd, :skip} | res]}

          {:ok, mod} ->
            case dispel_one(mod, info, ctx) do
              :ok ->
                {acc, [{cnd, :ok} | res]}

              {:ok, msg} ->
                {acc, [{cnd, {:ok, msg}} | res]}

              {:fail, msg} ->
                {Map.put(acc, cnd, info), [{cnd, {:fail, msg}} | res]}

              :skip ->
                {Map.put(acc, cnd, info), [{cnd, :skip} | res]}
            end
        end
      end)

    {if(map_size(remaining) == 0, do: nil, else: remaining), Enum.reverse(results)}
  end

  def dispel(_conditions, _ctx, _daemon), do: {nil, []}

  @doc """
  逐条件问 daemon 的 `min_qi_needed/1` / `min_jing_needed/1`，返回**第一个**
  当前 `qi`/`jing` 不达标的条件名；全都不拦则返回 `nil`。

  对应 LPC `cmds/std/sleep.c` 的门控：

  ```c
  if (CONDITION_D(kc[i])->min_qi_needed(me) > qi ||
      CONDITION_D(kc[i])->min_jing_needed(me) > jing)
          return 1;   // 睡不着
  ```

  `attributes` 传角色的 `attributes` 映射。本引擎有**两套键约定**并存：玩家
  `attributes` 是字符串键（`"qi"`），而 `ConditionEvent` 给 daemon 组装的
  `attributes` 是原子键（`con:`/`jing:`，见 `Kantele.Drunk.limit/1`）——
  这里两套都认，避免调用方踩坑。

  **门槛缺省按 0 计**（不拦），与 LPC「未实现该函数即返回 0」一致 ——
  目前 `kungfu/condition/` 下只有 `ill_*` 五族实现了这两个函数
  （`ill_dongshang`/`ill_fashao`/`ill_kesou` = 10，`ill_zhongshu` = 15，
  `ill_shanghan` = 20），`poison`/`drunk`/`nishui`/`duyan` 都不拦睡觉。
  """
  def blocked_by_vitals(conditions, attributes, daemon) when is_map(conditions) do
    attributes = attributes || %{}
    qi = vital(attributes, "qi", :qi)
    jing = vital(attributes, "jing", :jing)

    Enum.find_value(conditions, fn {cnd, _info} ->
      case daemon.(cnd) do
        :error ->
          nil

        {:ok, mod} ->
          if min_needed(mod, :min_qi_needed, attributes) > qi or
               min_needed(mod, :min_jing_needed, attributes) > jing do
            cnd
          end
      end
    end)
  end

  def blocked_by_vitals(_conditions, _attributes, _daemon), do: nil

  # ---- internal ----

  # 同时接受 "qi"（玩家 attributes）与 :qi（ConditionEvent 给 daemon 的 attributes）
  defp vital(attributes, string_key, atom_key) do
    case Map.get(attributes, string_key) do
      n when is_integer(n) ->
        n

      _ ->
        case Map.get(attributes, atom_key) do
          n when is_integer(n) -> n
          _ -> 0
        end
    end
  end

  defp min_needed(mod, fun, attributes) do
    if function_exported?(mod, fun, 1) do
      case apply(mod, fun, [attributes]) do
        n when is_integer(n) -> n
        _ -> 0
      end
    else
      0
    end
  end

  defp dispel_one(mod, info, ctx) do
    if function_exported?(mod, :dispel_condition, 2) do
      case mod.dispel_condition(info, ctx) do
        result when result in [:ok, :skip] -> result
        {:ok, msg} -> {:ok, msg}
        {:fail, msg} -> {:fail, msg}
        _ -> :skip
      end
    else
      :ok
    end
  end

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

defmodule Kantele.Character.Scheme do
  @moduledoc """
  计划自动执行器的纯逻辑层（对应 LPC cmds/usr/scheme.c 的
  `continue_scheme` / `execute_schedule` 控制流与逐步推进）。

  本模块不触碰 conn / 进程 / 命令执行；所有副作用（强制命令、定时、渲染）
  都由 `Kantele.Character.SchemeStepEvent` 负责。这样控制流可被独立单测，
  运行态用注入的 `runner` 模拟。

  ## 状态
  `%Scheme.State{steps, step, repeat_stack, last_fail}`
  - `steps`：计划按行拆出的步骤串（已滤空行）
  - `step`：当前步索引
  - `repeat_stack`：REPEAT/LOOP 配对栈，元素为 `{repeat_index, loop_index}`
  - `last_fail`：最近一次失败的 `System.system_time(:millisecond)`，用于 5 秒节流

  ## runner 约定
  `advance_step/2` 接收一个 `runner`（`fn cmd -> {:ok, extra} | {:error, extra} end`），
  生产环境里 `runner` 实际执行 `Kantele.Character.Commands.call(conn, cmd)` 并返回
  更新后的 conn（`extra`）；测试里则注入记录型 runner。控制流（REPEAT/LOOP/BREAK）
  与失败分支（RETRY/CONTINUE/BREAK/IGNORE/默认回退）完全由本模块决定，`runner`
  只负责「这一步命令跑没跑成」。
  """

  defstruct steps: [], step: 0, repeat_stack: [], last_fail: 0

  @control_commands ["REPEAT", "LOOP", "BREAK"]
  @repeat_stack_limit 12
  @fail_throttle_ms 5000
  @tick_delay_ms 1500

  alias Kantele.Character.Stats

  # ---------------------------------------------------------------------------
  # 解析 / 初始化
  # ---------------------------------------------------------------------------

  @doc "把 schedule 文本按行拆成步骤（trim 并滤掉空行）"
  def parse_steps(schedule) when is_binary(schedule) do
    schedule
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def init_state(steps) when is_list(steps),
    do: %__MODULE__{steps: steps, step: 0, repeat_stack: [], last_fail: 0}

  # ---------------------------------------------------------------------------
  # 当前步
  # ---------------------------------------------------------------------------

  @doc """
  返回 `:done`（已越界）或 `{index, cmd, case_action}`。
  `case_action` 为 `cmd:case` 中冒号后的「失败动作」，缺省为 `"IGNORE"`。
  """
  def current_step(%__MODULE__{steps: steps, step: step}) do
    if step < 0 or step >= length(steps) do
      :done
    else
      raw = Enum.at(steps, step)
      {cmd, case_action} = parse_case(raw)
      {step, cmd, case_action}
    end
  end

  defp parse_case(raw) do
    case String.split(raw, ":", parts: 2) do
      [cmd, case_action] -> {String.trim(cmd), String.trim(case_action)}
      [cmd] -> {String.trim(cmd), "IGNORE"}
    end
  end

  # ---------------------------------------------------------------------------
  # 推进一普通步（命令成功时）
  # ---------------------------------------------------------------------------

  @doc "成功推进一步；越界则返回 `{:done}`"
  def advance(%__MODULE__{steps: steps, step: step} = state) do
    new_step = step + 1

    if new_step >= length(steps) do
      {:done}
    else
      {:ok, %{state | step: new_step}}
    end
  end

  # ---------------------------------------------------------------------------
  # 控制流：REPEAT / LOOP / BREAK
  # ---------------------------------------------------------------------------

  @doc """
  REPEAT：向前扫描配对 LOOP（嵌套计数），找到后压栈并指向循环体首行。
  找不到配对 LOOP、或嵌套超过限制时返回 `{:cancel, reason}`。
  """
  def apply_repeat(%__MODULE__{} = state) do
    %__MODULE__{steps: steps, step: i, repeat_stack: stack} = state

    case find_loop(steps, i) do
      {:ok, loop_index} ->
        if length(stack) >= @repeat_stack_limit do
          {:cancel, "循环嵌套的层次太多，你的计划书好复杂，执行不了。\n"}
        else
          new_stack = stack ++ [{i, loop_index}]
          {:ok, %{state | step: i + 1, repeat_stack: new_stack}, "开始循环。\n"}
        end

      :not_found ->
        {:cancel, "计划中 repeat 没有找到与之匹配的 loop 命令，无法继续执行。\n"}
    end
  end

  @doc "LOOP：跳回最近一次 REPEAT 之后的循环体首行（REPEAT 行 + 1）"
  def apply_loop(%__MODULE__{repeat_stack: []}),
    do: {:cancel, "没有找到计划中与之匹配的 repeat 命令。\n"}

  def apply_loop(%__MODULE__{repeat_stack: stack} = state) do
    {repeat_start, _loop_idx} = List.last(stack)
    {:ok, %{state | step: repeat_start + 1}, "Loop.\n"}
  end

  @doc "BREAK：跳出最近一层循环，指向配对 LOOP 的下一行并弹栈"
  def apply_break(%__MODULE__{repeat_stack: []}),
    do: {:cancel, "没有找到计划中与之匹配的 repeat-loop 命令。\n"}

  def apply_break(%__MODULE__{repeat_stack: stack} = state) do
    {_repeat_start, loop_idx} = List.last(stack)
    new_stack = List.delete_at(stack, length(stack) - 1)
    {:ok, %{state | step: loop_idx + 1, repeat_stack: new_stack}, "Ok.\n"}
  end

  # 从 step+1 起扫描，计数法配对：
  #   LOOP 使 count-1，REPEAT 使 count+1；count 首次降到 <1 的 LOOP 即配对成功
  defp find_loop(steps, step) do
    find_loop(Enum.with_index(steps), step + 1, 1)
  end

  defp find_loop([], _from, _count), do: :not_found

  defp find_loop([{line, idx} | rest], from, count) when idx < from,
    do: find_loop(rest, from, count)

  defp find_loop([{line, idx} | rest], _from, count) do
    cond do
      line == "LOOP" ->
        if count - 1 < 1, do: {:ok, idx}, else: find_loop(rest, idx, count - 1)

      line == "REPEAT" ->
        find_loop(rest, idx, count + 1)

      true ->
        find_loop(rest, idx, count)
    end
  end

  # ---------------------------------------------------------------------------
  # 失败分支（命令失败时按 case_action 处理）
  # ---------------------------------------------------------------------------

  @doc """
  命令失败时的动作决策：
  - `"RETRY"` → `{:retry}`（5 秒节流后重试同一步）
  - `"CONTINUE"` → `{:loop}`（跳回循环体；无栈则取消）
  - `"BREAK"` → `{:break}`（跳出循环；无栈则取消）
  - `"IGNORE"` → `{:advance}`（忽略失败，继续下一步）
  - 其它（真实命令名）→ `{:fallback, cmd}`（执行该回退命令后继续）
  """
  def failure_action(_state, "RETRY"), do: {:retry}

  def failure_action(%__MODULE__{repeat_stack: []}, "CONTINUE"),
    do: {:cancel, "没有找到计划中与之匹配的 repeat 命令。\n"}

  def failure_action(_state, "CONTINUE"), do: {:loop}

  def failure_action(%__MODULE__{repeat_stack: []}, "BREAK"),
    do: {:cancel, "没有找到计划中与之匹配的 repeat-loop 命令。\n"}

  def failure_action(_state, "BREAK"), do: {:break}
  def failure_action(_state, "IGNORE"), do: {:advance}
  def failure_action(_state, case_action), do: {:fallback, case_action}

  def control?(cmd), do: cmd in @control_commands

  # ---------------------------------------------------------------------------
  # 单步决策（纯函数，runner 注入副作用）
  # ---------------------------------------------------------------------------

  @doc """
  根据当前态与 runner 计算「这一步该做什么」。返回标签元组，由事件处理器落地：

  - `{:done}`：已越界，计划完成
  - `{:ok, new_state, cmd, extra}`：命令成功，已推进（extra 为 runner 返回的 conn）
  - `{:done_cmd, cmd, extra}`：命令成功且是最后一步（extra 同上）
  - `{:control, new_state}`：REPEAT/LOOP/BREAK，未执行命令
  - `{:retry, new_state}`：失败+RETRY，未推进（5 秒节流后重试同一步）
  - `{:ignored, new_state}`：失败+IGNORE，忽略后继续
  - `{:done_ignored}`：失败+IGNORE 且是最后一步
  - `{:cancel, reason}`：结构错误（REPEAT 无 LOOP 等）
  """
  def advance_step(state, runner) when is_function(runner, 1) do
    case current_step(state) do
      :done ->
        {:done}

      {_idx, raw_cmd, case_action} ->
        if control?(raw_cmd) do
          case control(raw_cmd, state) do
            {:ok, ns, _msg} -> {:control, ns}
            {:cancel, reason} -> {:cancel, reason}
          end
        else
          case runner.(raw_cmd) do
            {:ok, extra} ->
              case advance(state) do
                {:ok, ns} -> {:ok, ns, raw_cmd, extra}
                {:done} -> {:done_cmd, raw_cmd, extra}
              end

            {:error, _extra} ->
              case failure_action(state, case_action) do
                {:retry} ->
                  {:retry, state}

                {:loop} ->
                  ctrl(apply_loop(state))

                {:break} ->
                  ctrl(apply_break(state))

                {:advance} ->
                  case advance(state) do
                    {:ok, ns} -> {:ignored, ns}
                    {:done} -> {:done_ignored}
                  end

                {:fallback, fb} ->
                  {_r, extra2} = runner.(fb)

                  case advance(state) do
                    {:ok, ns} -> {:ok, ns, fb, extra2}
                    {:done} -> {:done_cmd, fb, extra2}
                  end

                {:cancel, reason} ->
                  {:cancel, reason}
              end
          end
        end
    end
  end

  defp control("REPEAT", s), do: apply_repeat(s)
  defp control("LOOP", s), do: apply_loop(s)
  defp control("BREAK", s), do: apply_break(s)

  defp ctrl({:ok, ns, _}), do: {:control, ns}
  defp ctrl({:cancel, reason}), do: {:cancel, reason}

  # ---------------------------------------------------------------------------
  # `scheme start` 门控（纯函数，便于单测）
  # ---------------------------------------------------------------------------

  @doc "组合门控：计划存在 / 房间标志 / 实战经验 / 可用潜能 / 房间人数"
  def start_gate(schedule, flags, stats, player_count) do
    with :ok <- gate_schedule(schedule),
         :ok <- gate_room(flags),
         :ok <- gate_experience(stats),
         :ok <- gate_potential(stats),
         :ok <- gate_players(player_count) do
      :ok
    end
  end

  defp gate_schedule(schedule) when schedule in [nil, ""],
    do: {:error, "你目前还没有制订计划。\n"}

  defp gate_schedule(_), do: :ok

  defp gate_room(flags) when is_list(flags) do
    cond do
      "chat_room" in flags ->
        {:error, "你不能在聊天室里面执行计划。\n"}

      not ("sleep_room" in flags) ->
        {:error, "你必须在能够休息的地方才能执行计划。\n"}

      not ("no_fight" in flags) ->
        {:error, "你必须在安全的地方才能执行计划。\n"}

      true ->
        :ok
    end
  end

  defp gate_room(_), do: :ok

  defp gate_experience(stats) do
    if (Map.get(stats, :combat_exp) || 0) < 50_000 do
      {:error, "你的实战经验太浅薄，还是先好好锻炼锻炼再说吧。\n"}
    else
      :ok
    end
  end

  defp gate_potential(stats) do
    if Stats.available_potential(stats) < 100 do
      {:error, "你的潜能太少，难以开展计划。\n"}
    else
      :ok
    end
  end

  defp gate_players(count) when is_integer(count) and count > 12,
    do: {:error, "这里的人实在太多了，你难以静心开展计划。\n"}

  defp gate_players(_), do: :ok

  # ---------------------------------------------------------------------------
  # 常量（事件处理器 / 命令复用）
  # ---------------------------------------------------------------------------

  def fail_throttle, do: @fail_throttle_ms
  def tick_delay, do: @tick_delay_ms
end

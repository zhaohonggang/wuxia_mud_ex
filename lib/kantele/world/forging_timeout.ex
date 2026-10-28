defmodule Kantele.World.ForgingTimeout do
  @moduledoc """
  锻造链的 `call_out` 定时**原语**（对应 LPC `moye.c time_out` 与 `ganjiang.c waiting`）。

  本仓没有 LPC 的 `call_out`，用 `Process.send_after/3` 把事件投回**调用方自己**
  （莫邪或干将的角色进程），再由 `Kalevala.Character.Foreman` 的 `%Event{}` 分支
  分发到 `Kantele.Character.ForgingTimeoutEvent` 的处理器 —— 与 `exercise/tick`、
  `combat/tick` 同一套做法。

  本模块只负责「排 / 取消 / 校验令牌」，不含业务；业务在 `ForgingTimeoutEvent`。

  ## 两条定时链

  | LPC | 触发点 | 周期 | 行为 |
  |---|---|---|---|
  | `moye.c time_out` | 玩家交出材料/乾坤石（`item_gived`） | 30s 一次性 | 退款退料，会话清空 |
  | `ganjiang.c waiting` | 干将 step_6 进入起名阶段 | 首次 240s，之后每 300s，共 4 次 | 催prompt；4 次后销毁成品且**不退款** |

  ## 陈旧定时器的作废

  LPC 用 `remove_call_out` 取消。本仓不持有定时器引用，改用**令牌**：每次排程往
  会话写一个新的 `:timer_token`，定时事件带上排程时的令牌；触发时令牌与会话不符，
  说明这条链已被新排程取代（玩家重给材料 / 已 `answer` 交干将 / 已退款），直接忽略。

  这样跨进程（莫邪排程、玩家进程改会话）也不会漏取消。

  ## 时间缩放

  `config :ex_venture, :forge_timing_scale` 乘在秒数上：生产 1（真实时间），
  测试 0（立即投递，便于 `assert_receive` 后手动驱动下一跳）。
  """

  alias Kalevala.Event
  alias Kantele.World.Forging

  # LPC 常量（秒）
  @quote_timeout 30
  @waiting_first 240
  @waiting_next 300
  @max_waited 4

  @doc "干将等待次数上限（LPC `set_temp(\"item/waited\", 4)`）"
  def max_waited, do: @max_waited

  @doc "首次等待秒数（LPC `call_out(\"waiting\", 240, ...)`）"
  def waiting_first, do: @waiting_first

  @doc "后续等待秒数（LPC `waiting` 里递归重排的 300s）"
  def waiting_next, do: @waiting_next

  @doc "报价超时秒数（LPC `call_out(\"time_out\", 30, ...)`）"
  def quote_timeout_seconds, do: @quote_timeout

  @doc """
  排一条定时事件：把 `%Event{topic: topic}` 在 `seconds` 秒后投给**当前进程**。

  会话不存在时什么也不做（玩家可能已经放弃）。返回本次令牌，供 `valid?/2` 校验。
  """
  def schedule(owner_id, topic, seconds, extra \\ %{}) do
    case Forging.get(owner_id) do
      nil ->
        nil

      session ->
        token = new_token()
        Forging.put(owner_id, Map.put(session, :timer_token, token))

        Process.send_after(
          self(),
          %Event{
            from_pid: self(),
            topic: topic,
            data: Map.merge(extra, %{owner_id: owner_id, token: token})
          },
          delay_ms(seconds)
        )

        token
    end
  end

  @doc "作废当前链上的所有定时器（不删会话）。对应 LPC `remove_call_out`。"
  def cancel(owner_id) do
    case Forging.get(owner_id) do
      nil -> :ok
      session -> Forging.put(owner_id, Map.put(session, :timer_token, new_token()))
    end

    :ok
  end

  @doc "定时事件是否仍然有效（会话还在，且令牌没被后续排程替换）。"
  def valid?(owner_id, token) do
    case Forging.get(owner_id) do
      %{} = session -> Map.get(session, :timer_token) == token
      _ -> false
    end
  end

  defp new_token, do: :erlang.unique_integer([:positive, :monotonic])

  defp delay_ms(seconds) do
    scale = Application.get_env(:ex_venture, :forge_timing_scale, 1)
    max(round(seconds * 1000 * scale), 0)
  end
end

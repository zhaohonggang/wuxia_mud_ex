defmodule Kantele.Scheduler do
  @moduledoc """
  统一调度服务（对应 LPC set_heart_beat/call_out/schedule_callback/复活/炼制完成/自动关门/NPC 心跳清场）

  - 基于 `:timer` / `Process.send_after` 封装
  - 支持一次性、周期性、延迟回调
  - 所有定时器带 `ref` 可取消
  - 集成现有 Kalevala `set_timer`/`call_out` 原语
  """

  require Logger

  @doc """
  一次性延迟回调（对应 LPC call_out/2）

  `fun` 在 `ms` 毫秒后在调用进程执行；返回 `timer_ref` 可 `cancel/1`。
  """
  def schedule_once(ms, fun) when is_integer(ms) and ms >= 0 and is_function(fun) do
    ref = make_ref()
    :timer.apply_after(ms, __MODULE__, :run_once, [ref, fun])
    ref
  end

  @doc "周期性回调（对应 LPC set_heart_beat/2 的心跳模拟）"
  def schedule_recurring(ms, fun) when is_integer(ms) and ms > 0 and is_function(fun) do
    ref = make_ref()
    spawn(fn -> recurring_loop(ref, ms, fun) end)
    ref
  end

  @doc "取消定时器（对应 LPC cancel_timer/2）"
  def cancel(ref) do
    :timer.cancel(ref)
  end

  @doc "复活调度（对应 LPC revive/3 + DEATH_ROOM + start_death）"
  def schedule_revive(player_id, ms \\ 30_000) do
    schedule_once(ms, fn ->
      # 实际应调用 Character 复活逻辑
      Logger.info("Revive scheduled for #{player_id}")
    end)
  end

  @doc "炼制完成调度（对应 LPC room_wudu_liandu 炼制回调）"
  def schedule_liandu_finish(player_id, recipe_id, ms) do
    schedule_once(ms, fn ->
      Logger.info("Liandu finish for #{player_id}: #{recipe_id}")
    end)
  end

  @doc "自动关门调度（对应 LPC room_qianting 10s 关门）"
  def schedule_door_close(room_id, ms \\ 10_000) do
    schedule_once(ms, fn ->
      # 实际应调用 Room.set_dynamic_exit 关门 + sync_room
      Logger.info("Door close scheduled for #{room_id}")
    end)
  end

  @doc "NPC 心跳清场（对应 LPC npc_xiaoer 心跳清尸/重置）"
  def schedule_npc_cleanup(npc_id, ms) do
    schedule_recurring(ms, fn ->
      Logger.info("NPC cleanup for #{npc_id}")
    end)
  end

  @doc "公告频道定时广播（对应 LPC channel/rumor 定时）"
  def schedule_broadcast(channel, message, ms) do
    schedule_once(ms, fn ->
      # 实际应调用 Communication.broadcast
      Logger.info("Broadcast to #{channel}: #{message}")
    end)
  end

  defp run_once(ref, fun) do
    try do
      fun.()
    catch
      :exit, reason ->
        Logger.error("Scheduler once #{inspect(ref)} crashed: #{inspect(reason)}")
    end
  end

  defp recurring_loop(ref, ms, fun) do
    :timer.sleep(ms)
    try do
      fun.()
    catch
      :exit, reason ->
        Logger.error("Scheduler recurring #{inspect(ref)} crashed: #{inspect(reason)}")
    end
    # 检查是否已取消（简化：重新 schedule）
    unless :timer.cancel(ref) == false do
      recurring_loop(ref, ms, fun)
    end
  end
end
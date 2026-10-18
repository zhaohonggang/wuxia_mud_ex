defmodule Kantele.World.NpcActions.CallOut do
  @moduledoc """
  LPC `call_out(function, delay, args...)` 的 NPC 版（P5-1c，full `bi` 前置）。

  LPC 的 `call_out` 在 `this_object()`（即 NPC）上延迟若干心跳后调用一个函数，
  例如 `d/tulong/tulong/npc/mai.c`：

      call_out("guo", 6, me);   // 6 拍后把玩家 me 交给麦鲸自己的 guo()

  本引擎没有通用 `call_out`（`Kantele.Scheduler` 里的 `schedule_*` 多为日志桩，
  `schedule_callback/2` 甚至是「调用了但未定义」的坏桩）。这里用最小可用实现：

  - `Process.send_after/3` 把一个 `"npc/call-out"` 事件投给 NPC foreman 进程
    （`character.pid`，见 `Kalevala.Character.Foreman.NonPlayer.init/2` 里
    `%{opts.character | pid: self()}`）；
  - `Kantele.Character.CallOutEvent` 收到后回调
    `apply(module, function, [conn | args])`。

  LPC 心跳约 1s，故 `delay_units`（LPC 第二参数）按 1s/拍换算。
  """

  alias Kalevala.Event

  @topic "npc/call-out"
  @unit_ms 1000

  @doc "`\"npc/call-out\"` 主题（供 NonPlayerEvents 注册）"
  def topic, do: @topic

  @doc """
  在 `npc` 上安排一次延迟回调。

  - `npc`：带 `:pid` 的 NPC 角色（房间快照）
  - `module`/`function`：目标 MFA（如 `Kantele.World.NpcActions.Mai`/`:guo`）
  - `delay_units`：延迟拍数（LPC `call_out` 第二参数）
  - `args`：追加在 `conn` 之后传给目标函数的参数

  返回 `:ok`（已投递）或 `{:error, :no_process}`（NPC 无活进程）。
  """
  def schedule(npc, module, function, delay_units, args \\ [])
      when is_atom(module) and is_atom(function) and is_integer(delay_units) do
    case Map.get(npc, :pid) do
      pid when is_pid(pid) ->
        event = %Event{
          acting_character: npc,
          from_pid: self(),
          topic: @topic,
          data: %{module: module, function: function, args: args}
        }

        Process.send_after(pid, event, delay_units * @unit_ms)
        :ok

      _ ->
        {:error, :no_process}
    end
  end
end

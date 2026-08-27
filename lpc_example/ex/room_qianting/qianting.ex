defmodule ExKantele.World.Room.Qianting do
  @moduledoc """
  对应原文件: lpc_example/room/room_qianting.c —— 大门状态机行为半。

  迁移判定: C —— 需底层能力才能落：
    - room_verbs 自定义动词（push / close）
    - 动态 exit（gate 开才有 north 出口）
    - 定时器（10 秒后自动关）-> 现有 Room.Processor 无 call_out/心跳
    - valid_leave 出房拦截钩子

  原大门状态机（faithful）:
    gate: close {north exits 不存在}  --push--> open {north exits=__DIR__zoudao}
    open {zoudao.south=本房间}        --close(手动/10s超时)--> close
    只有 saodi laopu 的老家人/主人/被许可者可通 north（valid_leave）。
  """

  defstruct [:gate, north_exit?: false]

  def push(%__MODULE__{gate: :open}), do: {:already_open, "大门开着呢，你还推什么？"}
  def push(%__MODULE__{gate: :close}) do
    {:ok, %__MODULE__{gate: :open, north_exit?: true}}   # 并给 zoudao.south 加出口
  end

  def close(%__MODULE__{gate: :close}), do: {:already_closed, "大门关着呢，你还再关一遍？"}
  def close(%__MODULE__{gate: :open}) do
    {:ok, %__MODULE__{gate: :close, north_exit?: false}} # 并删 zoudao.south 出口
  end

  # 10 秒超时自动关（原 call_out("do_close",10,0,1)）
  def auto_close(conn), do: gen_event_push(conn, :qianting_gate_timer, 10_000)
end

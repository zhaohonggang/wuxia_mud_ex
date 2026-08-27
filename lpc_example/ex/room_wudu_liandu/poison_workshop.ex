defmodule ExKantele.World.Room.PoisonWorkshop do
  @moduledoc """
  对应原文件: lpc_example/room/room_wudu_liandu.c —— 炼毒行为半。

  迁移判定: C —— 需底层 room_verbs + 持久化炼毒进度。
  原文多阶段炼毒: 数暗号 -> 看时辰 -> 下料 -> 产出指定毒药 + 毒方图样。
  对应 Room.Processor 事件处理器(也见 inherit_room_pigroom)。
  """

  # 阶段状态机
  defstruct [:stage, :recipe]

  @note "需 room_verbs + 炼毒进度持久化"
end

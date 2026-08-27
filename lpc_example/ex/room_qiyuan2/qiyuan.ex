defmodule ExKantele.World.Room.Qiyuan do
  @moduledoc """
  对应原文件: lpc_example/room/room_qiyuan2.c —— 奇缘随机事件行为半。

  迁移判定: C —— 需底层 room_heart_beat + 玩家状态(karma/score/random)查询。
  大型互动房间，look/zhao 等触发随机多分支事件。
  """

  @note "依赖 room_heart_beat 与随机分支；也见 inherit_room_pigroom"
end

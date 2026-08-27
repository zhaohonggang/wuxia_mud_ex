defmodule ExKantele.World.Room.BaseInteractive do
  @moduledoc """
  对应原文件: lpc_example/inherit/room_pigroom.c (可交互房间基类, 20901B)

  迁移判定: C —— **框架要新增的房间交互能力**，非世界数据。
  正确做法是把这些通用钩子并入 Kantele.World.Room / Room.Processor，
  让所有 UCL 房间都能注册动词和心跳。

  原文 pigroom.c 展示/要求的基础能力:
    - reset 定期重置房间(怪物重生/机关复位)
    - add_action("cmd") 房间自定义动词
    - set_heart_beat(1) 房间逐 tick 心跳(时间/事件推进)
    - 多方向动态 exit(也见 room_qianting 的大门状态机)
  """

  @required_framework_additions [
    room_heart_beat: "Room.Processor 需支持自定义 tick",
    room_verbs: "UCL rooms 增加 verbs/actions 段 + 自定义动词分发",
    dynamic_exits: "exit 由房间状态机改写(现有 room_exits 静态表)",
    reset: "房间定时 reset 钩子"
  ]
end

defmodule ExKantele.World.Npc.Base do
  @moduledoc """
  基础 NPC 行为（对照 lpc_example/inherit/inherit_char_npc.c）

  结论：这是**框架要新增的基础行为 mixin**，不是世界数据。
  它相当于把“所有 NPC 都该有”的通用钩子并入 Kantele 的 NPC/UCL 加载层，
  与房间 base 一样，属于一次性底层开发，而非逐文件迁移。

  原文 expose 的通用能力（当前 UCL `characters` 不覆盖的部分）：
  - set_name/set_long/name/长描述：已有，映射 UCL name/description
  - set("chat_chance", n)：随机说话概率
  - add_action / set_heart_beat：用户动词与逐 tick 心跳（房间/物品同理）
  - is_killing：击杀仇恨
  - unconcious()：受击转昏迷
  - receive_damage / receive_wound：伤害双血条（见 damage feature）

  结论：这些应成为 `Kantele.World.Characters.Base`（或并入 Character 有状态进程）
  的内置回调，一次开发对所有 NPC 生效；不打散进各 NPC 文件。
  """

  @required_framework_additions [
    chat_chance: "UCL 增加 chat_chance / chat_msg 字段并由加载层注册心跳",
    add_action: "通用 add_action 动词注册（用于 set_heart_beat 之外的交互）",
    is_killing: "击杀仇恨列表维护",
    unconcious: "vitals 归零转昏迷的自动转移"
  ]
end

defmodule ExKantele.World.Room.BaseInteractive do
  @moduledoc """
  可交互房间基类（对照 lpc_example/inherit/room_pigroom.c、room_qianting.c）

  结论：**框架要新增的房间交互能力**（heart_beat + add_action + input_to），
  不是世界数据，也不该写成“每个房间都带一整份该样板”。正确做法是把这些
  通用钩子并入 `Kantele.World.Room`，让所有 UCL 房间都能注册动词和心跳。

  原文 pigroom.c 展示/要求的基础能力：
  - `reset`：定期重置房间状态（怪物重生/机关复位）
  - `add_action("cmd")`: 给房间加自定义动词
  - `set_heart_beat(1)`：房间逐 tick 心跳（时间流逝/事件推进）
  - 多方向动态 exit（qianting 的大门 gate 状态机）
  """

  @required_framework_additions [
    room_heart_beat: "Room.Processor 需支持自定义 tick（现有仅 look/移动类事件）",
    room_verbs: "UCL rooms 增加 verbs/actions 段 + Room.Processor 分发自定义动词事件",
    dynamic_exits: "exit 可由房间状态机改写（gate 开关），现有 room_exits 是静态表",
    reset: "房间定时 reset 钩子（重生物/机关）"
  ]
end

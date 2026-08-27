defmodule ExKantele.World.Npc.Base do
  @moduledoc """
  对应原文件: lpc_example/inherit/inherit_char_npc.c (基础NPC, 15294B)

  迁移判定: C —— **框架要新增的基础行为 mixin**，非世界数据。
  这是“所有 NPC 都该有”的通用钩子，应一次并入 Kantele 的 NPC/加载层，
  让所有 characters 生效，而非逐文件迁移。

  原文暴露的通用能力（当前 UCL characters 未覆盖）:
    - set_name/set_long/name/long            -> UCL name/description 已有
    - set("chat_chance", n)                  随机说话概率(心跳)
    - add_action / set_heart_beat            自定义动词 + 逐 tick 心跳
    - is_killing                             击杀仇恨
    - unconcious / receive_damage / receive_wound  双血条(见 feature_damage)
  """

  @required_framework_additions [
    chat_chance: "UCL 增加 chat_chance/chat_msg 字段并由加载层注册心跳",
    add_action: "通用 add_action 动词注册",
    is_killing: "击杀仇恨列表维护",
    unconcious: "vitals 归零转昏迷"
  ]
end

defmodule ExKantele.World.Item.Qianzhumiji do
  @moduledoc """
  千蛛万毒手秘笈（对照 lpc_example/item/item_wudu_qianzhumiji.c）

  数据半 → lpc_samples.ucl 的 items.qianzhumiji（book 字段）。
  行为半：研读/research + 多绝招解锁 + 出毒学习进度 ← 需要“带状态的物品”。

  Kalevala 已有 `Kantele.World.Item.InteractiveItem`（iitem 动词机制），
  本模块基于它注册 yanjiu/research/du 三个动词，并把 LPC 的绝招解锁逻辑
  转成行为动作：读一次解锁一个绝招（perform/prepare），依赖进度存储。
  """

  use Kalevala.World.Item.InteractiveItem, verb: "yanjiu"
  use Kalevala.World.Item.InteractiveItem, verb: "research"
  use Kalevala.World.Item.InteractiveItem, verb: "du"

  # 原文 book 里按绝招学习：识字/read -> learn_skill(qianzhu-wandushou)
  # 研究时才可学绝招：can_perform(...,<duodu>."/<花名>")
  @unsupported [
    research_progress: "每读一次解锁一个绝招的进度需存…… InteractiveItem 需支持持久化进度",
    skill_depend_unlock: "绝招需先读到对应 skill 等级才可解锁（读-学联动）"
  ]
end

defmodule ExKantele.World.Item.Yinzhen do
  @moduledoc """
  银针（对照 lpc_example/item/item_yinzhen.c）

  数据半 → lpc_samples.ucl 的 items.yinzhen（throwing + damage）。
  行为半：针灸疗伤（zhenjiu）动词，内含完整招式（force/unarmed/skill checks）。
  基于 InteractiveItem 注册 zhenjiu / heal，转成 healing 动作。
  """

  use Kalevala.World.Item.InteractiveItem, verb: "zhenjiu"

  @notes [
    "LPC zhenjiu 需 force/unarmed/skill 判级（见原文件完整 checks），映射到治疗动作时要复用本 skill",
    "针灸对扭伤才有效，需检查 target 的 wound 状态（见 damage/wound 语义）"
  ]
end

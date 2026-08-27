defmodule ExKantele.World.Item.Qianzhumiji do
  @moduledoc """
  对应原文件: lpc_example/item/item_wudu_qianzhumiji.c —— 研读行为半。

  迁移判定: C —— 行为需底层：
    - InteractiveItem 持久化“已解锁绝招进度”（每读一次解锁一个）
    - 与 qianzhu-wandushou 技能等级联动（skill 到位才能解锁下下个）
    - 解锁 -> can_perform(prepare) 绝招

  原文机制（概要）:
    - book 是“秘籍”，先识字/读，再 research/du 逐个解锁 perform
    - 每次研读消耗，随 skill 提升解锁更多绝招（yin/du 等）
  """

  use Kalevala.World.Item.InteractiveItem, verb: "yanjiu"
  use Kalevala.World.Item.InteractiveItem, verb: "research"
  use Kalevala.World.Item.InteractiveItem, verb: "du"

  def yanjiu(context, %{target: nil}) do
    # 解锁下一个未学绝招；若 skill 未达门槛则提示继续练 qianzhu-wandushou
    # 成功 -> grant perform_<skill>/<name>
    context
  end
end

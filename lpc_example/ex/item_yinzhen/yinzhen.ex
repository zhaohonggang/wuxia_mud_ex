defmodule ExKantele.World.Item.Yinzhen do
  @moduledoc """
  对应原文件: lpc_example/item/item_yinzhen.c —— 针灸 zhenjiu 行为半。

  迁移判定: C —— 行为无法单文件直落，需底层能力：
    - `eff_qi` 双血条（receive_wound / 治疗上限 max_qi）   [feature_damage]
    - `start_busy` 硬直轮                                  [feature_attack]
    - `improve_skill` 提高 zhenjiu-shu 熟练                [框架需有技能经验]
    - `is_killing` 仇恨判断                                [feature_attack]

  此处给出行为骨架（事件处理器形态）；真正接入需先把上述能力补齐。
  原判定流程（faithful 顺序）:
    1) 需会 zhenjiu-shu
    2) 银针必须在手(handing)
    3) 目标为活人/未昏迷
    4) 非玩家需 zhenjiu-shu>=60；玩家只能给自己/不可给玩家
    5) not busy / not fighting / 目标 force<300
    6) eff_qi>%5 时才安全；neili/jing 检查
    7) 冷却 last/zhenjiu 60s
    8) 消耗并 improve_skill
    9) 成功率 random(120)>skill 则失手(刺伤 receive_wound)，否则治伤
  """

  use Kalevala.World.Item.InteractiveItem, verb: "zhenjiu"

  def zhenjiu(context, %{target: target}) do
    # 依据原文件 do_heal 的逐条检查返回相应提示/动作
    with :ok <- check_skill(context),
         :ok <- check_handing(context),
         :ok <- check_target(context, target),
         :ok <- check_busy(context),
         :ok <- check_force(context, target),
         :ok <- check_vitals(context, target),
         :ok <- check_cd(context, target) do
      # 成功：扣 neili/jing、start_busy、improve_skill、结算 heal/damage
      heal(context, target)
    end
  end
end

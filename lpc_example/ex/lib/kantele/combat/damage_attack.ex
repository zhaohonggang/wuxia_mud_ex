defmodule ExKantele.Combat.Damage do
  @moduledoc """
  伤害结算模块（对照 lpc_example/feature/feature_damage.c）

  结论：这是**框架逻辑**，对应既有的 `Kantele.Combat.Engine` / `Kantele.Combat.Messages`。
  不是世界数据，单文件无法直落，需把它们并入（或替换）战斗引擎。

  原文（feature_damage.c）职责：
  - receive_damage / receive_wound：qi / eff_qi 两套血条
  - die() / unconcious()：死亡与昏迷转移
  - 护甲/防御减伤：`damage -= apply` 结算后被 armor 抵扣
  """

  # 伤害类型与落点映射（LPC receive_wound("qi", n)）
  def wound_apply(stat), do: stat   # qi -> qi；eff_qi 关联见下

  def die(_character), do: :die
  def unconcious(_character), do: :unconcious

  # 需底层确认：现有 Vitals 是否支持 eff_qi 与 max_qi 分离（示例 liuxi 只有 qi/max_qi）
  @unsupported [eff_qi: "Vitals 需增加 eff_qi/eff_jing 字段以支持 receive_wound"]
end

defmodule ExKantele.Combat.Attack do
  @moduledoc """
  攻击模块（对照 lpc_example/feature/feature_attack.c）

  结论：框架逻辑，对应既有 `Kantele.Combat.Engine` / `Kantele.Character.Combat`。
  原文提供 attack() / hit_ob() / 敌人列表（enemy / opponent）。

  当前 Kalevala 的战斗（combat/start、combat/strike 等）已有敌人管理，
  但缺少 LPC 的 `is_killing`（击杀列表）、`kill_ob`（点名追杀）、
  `start_busy`（busy 状态）等。这些需补进 Warrior/Combat 底层。
  """

  @unsupported [
    is_killing: "击杀仇恨列表（LPC is_killing / kill_ob）",
    start_busy: "战斗中的 busy / 硬直轮数（现有 Combat.busy 是整型计数，语义需对齐）",
    action_flag: "招式触发的瞬时效用标记"
  ]
end

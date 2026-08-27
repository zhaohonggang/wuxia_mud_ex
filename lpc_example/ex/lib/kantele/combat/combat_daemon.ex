defmodule ExKantele.Combat.CombatDaemon do
  @moduledoc """
  combatd.c 守护进程（对照 lpc_example/daemon/daemon_combatd.c，79KB）

  结论：这是**框架的核心战斗引擎**，绝不可能是单文件世界数据。
  它对应 Kalevala 已经存在的 `Kantele.Combat.Engine`（攻击/命中/伤害判定），
  以及只读展示用的 `Combat.Messages`。migrate 的正确姿势是：
  “不要搬 combatd.c，而是把它里的**数值公式/规则**提炼成语义注释，落到引擎”。

  原文 combatd.c 主要职责（本 MUD 已在 lib/kantele/combat/engine.ex 有对应）：
  - do_attack / do_status_attack / do_parry / do_dodge：命中/招架/闪避判定
  - damage 计算：随机化（drandom）、护甲抵扣、招式 damage + force 加成
  - 武器 skill_type 校验（空手/兵刃）
  - busy 判定、晕眩转移
  - 死亡/掉落
  """

  # 命中判定（LPC）：
  #   attack_skill vs dodge_skill/parry_skill，再经 apply 加成，
  #   以 (attack - defense) 为阈值比较。既有 Combat.Engine 应已实现。
  def hit?(_attacker, _defender), do: true

  # 伤害公式样例（LPC）：
  #   damage = base + random(force加成)... 再被 armor 抵扣
  def compute_damage(base, armor), do: max(base - armor, 0)

  # “占位/确认”标记：无需移植，规则并入 engine 即可
  @note "不产生独立 .ex；把数值规则并入 Kantele.Combat.Engine"
end

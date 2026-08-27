defmodule ExKantele.Combat.CombatDaemon do
  @moduledoc """
  对应原文件: lpc_example/daemon/daemon_combatd.c (战斗守护, 79280B)

  迁移判定: C —— **框架核心战斗引擎**，绝非单文件世界数据。
  它对应 Kalevala 已有的 Kantele.Combat.Engine + Messages。
  正确姿势：不搬 combatd.c，而是把其中的数值公式/规则提炼成语义，并入引擎。

  原文主要职责(对应引擎)：
    - do_attack / do_status_attack / do_parry / do_dodge  命中/招架/闪避
    - damage 计算(随机化/护甲抵扣/damage+force 加成)
    - 武器 skill_type 校验(空手/兵刃)
    - busy 判定、晕眩转移、死亡/掉落
  """

  def hit?(_attacker, _defender), do: true

  def compute_damage(base, armor), do: max(base - armor, 0)

  @note "不产生独立 .ex 文件；把数值规则并入 Kantele.Combat.Engine"
end

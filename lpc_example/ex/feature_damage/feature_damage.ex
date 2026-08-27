defmodule ExKantele.Combat.Damage do
  @moduledoc """
  对应原文件: lpc_example/feature/feature_damage.c (伤害, 15000B)

  迁移判定: C —— **框架逻辑**。对应 Kantele.Combat.Engine / Messages。
  非世界数据、非单文件；需并入/替换战斗引擎。

  原文职责:
    - receive_damage / receive_wound：qi / eff_qi 双血条
    - die() / unconcious()：死亡与昏迷转移
    - 护甲/防御减伤
  需底层: Vitals 增加 eff_qi/eff_jing（当前只有 qi/max_qi）。
  """

  def wound_apply(stat), do: stat

  def die(_character), do: :die
  def unconcious(_character), do: :unconcious

  @unsupported [eff_qi: "Vitals 需增加 eff_qi/eff_jing 以支持 receive_wound"]
end

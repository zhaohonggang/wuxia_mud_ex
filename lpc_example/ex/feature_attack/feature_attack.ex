defmodule ExKantele.Combat.Attack do
  @moduledoc """
  对应原文件: lpc_example/feature/feature_attack.c (攻击, 13069B)

  迁移判定: C —— **框架逻辑**。对应 Kantele.Combat.Engine / Character.Combat。
  需底层补:
    - is_killing 击杀仇恨列表 / kill_ob 点名追杀
    - start_busy 战斗硬直轮
    - action_flag 招式瞬时效用
  """

  @unsupported [
    is_killing: "击杀仇恨列表（LPC is_killing / kill_ob）",
    start_busy: "战斗 busy/硬直轮",
    action_flag: "招式触发瞬时效用标记"
  ]
end

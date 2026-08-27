defmodule ExKantele.World.Npc.Xiaoer do
  @moduledoc """
  对应原文件: lpc_example/npc/npc_xiaoer.c —— 行为半(店小二)。

  迁移判定: C —— 大量 NPC 交互钩子当前框架(UCL characters)均无：
    - accept_object 收受物品（收金币 set rent_paid / 收尸）
    - greeting 进门随机招呼
    - do_drop 丢尸体被赶（需 drop 拦截 + receive_damage/unconcious）
    - do_exchange 积分兑换（需 state/jifen 玩家字段 + 兑奖问询）
    - heart_beat 满座清场（需 room 清单 + move 出房）

  这些应并入“通用 NPC 基类钩子”（也见 inherit_char_npc），一次开发全局生效。
  """

  # 积分兑换表（原文 do_exchange 的 switch，cost -> 物品）
  @exchange [
    {"血菩提", 5, "pill/puti1"}, {"舍利子", 5, "pill/sheli1"}, {"昊天果", 5, "pill/linghui1"},
    {"壮骨粉", 5, "gift/con1"}, {"福寿膏", 5, "gift/dex1"}, {"增慧丹", 5, "gift/int1"},
    {"神力丸", 5, "gift/str1"}, {"洗髓再造仙丹", 50, "gift/con3"}
  ]

  def exchange_cost(name), do: Enum.find_value(@exchange, fn {n, c, _} -> if n == name, do: c end)
end

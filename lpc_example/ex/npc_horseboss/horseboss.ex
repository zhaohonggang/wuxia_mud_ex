defmodule ExKantele.World.Npc.Horseboss do
  @moduledoc """
  对应原文件: lpc_example/npc/npc_horseboss.c —— 宠物街向导(行为半)。

  迁移判定: C —— 核心是“多阶段 input_to 向导”：
    choose -> 玩家回车/输入 -> 选种 -> 确认 -> 生成随机属性坐骑给玩家。
  当前框架无 `input_to`（多步命令行输入）机制，需在 Character.Conn/输入层新增，
  之后所有向导型 NPC(选坐骑/算命/拜师对话)都可复用。

  另需：随机生成坐骑属性的“生成器”（类似 class_generate_chinese 的工具），
  以及把生成出的坐骑作为 characters 数据实例挂给玩家。
  """

  # 骨架：两阶段状态机
  def handle_input(%{pending: {:choose_pet, step}}, input) do
    # step 推进：选种 -> 随机生成 -> 进玩家背包/骑乘
    {:ok, next_step}
  end
end

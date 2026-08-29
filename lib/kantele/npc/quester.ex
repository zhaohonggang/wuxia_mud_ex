defmodule Kantele.Npc.Quester do
  @moduledoc """
  任务发布 NPC（对应 `feature/quester.c`）

  - `is_quester?/1`: 识别
  - `ask_quest/2` / `cancel_quest/2`: 委托 `Kantele.Quest` 服务（占位，宿主接入）
  """

  @doc "任务 NPC 识别 (LPC: is_quester)"
  def is_quester?(_self), do: true

  @doc "请求任务（LPC: ask_quest(who) -> QUEST_D->ask_quest）"
  def ask_quest(self, who), do: Kantele.Quest.ask_quest(self, who)

  @doc "取消任务（LPC: cancel_quest(who) -> QUEST_D->cancel_quest）"
  def cancel_quest(self, who), do: Kantele.Quest.cancel_quest(self, who)
end

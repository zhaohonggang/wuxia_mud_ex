defmodule Kantele.Quest do
  @moduledoc """
  任务服务（对应 LPC `QUEST_D`，被 `feature/quester.c` 委托调用）

  目前为占位桩：宿主接入 `Quest` 引擎后实现真正派发。返回
  `{:error, :not_implemented}`。
  """

  @doc "请求任务（LPC: QUEST_D->ask_quest(npc, who)）"
  def ask_quest(_npc, _who), do: {:error, :not_implemented}

  @doc "取消任务（LPC: QUEST_D->cancel_quest(npc, who)）"
  def cancel_quest(_npc, _who), do: {:error, :not_implemented}
end

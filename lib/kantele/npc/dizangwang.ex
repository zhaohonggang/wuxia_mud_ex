defmodule Kantele.NPC.Dizangwang do
  @moduledoc """
  地藏王 NPC 问询处理器（对应 LPC `d/death/npc/dizangwang.c` 的 `ask_zhuan` 四前置链）。

  玩家于地府向地藏王 `ask 转世` 触发转世重生。本处理器仅作「问询 → 触发」桥接：
  前置判定与转世主体逻辑全部在 `Kantele.Character.Reborn`（忠实移植 `updated.c`
  的 `zhuan_player` 及 `ask_zhuan` 前置链）。四前置齐备方可进入六道轮回。

  前置（与 LPC `ask_zhuan` + 计划 D2 一致）：
    ① 大宗师（combat_exp≥800000000）
    ② 十八层地狱 `meta.env[:HellZhenPass]`
    ③ 击败地藏王 `meta.env[:DiZangPass]`
    ④ 十二重天·献精元丹 `meta.env[:SkyPass]`
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.Reborn

  @impl true
  def ask_specs do
    %{
      "转世" => %{
        check: fn asker, _npc ->
          if Reborn.prereqs_met?(asker) do
            :ok
          else
            {:error, Reborn.refusal_message(Reborn.missing_prereqs(asker))}
          end
        end,
        execute: fn asker, _npc -> do_reborn(asker) end,
        effects: [{:reborn}]
      }
    }
  end

  defp do_reborn(asker) do
    case Reborn.trigger(asker) do
      {:ok, new_char} ->
        if pid = asker.pid, do: send(pid, {:room_message, "六道轮回轰然转动，你重入轮回，再世为人……\n"})
        {:ok, new_char}

      {:error, msg} ->
        if pid = asker.pid, do: send(pid, {:room_message, msg})
        {:error, msg}
    end
  end

  @impl true
  def check(asker, npc, keyword), do: dispatch(:check, asker, npc, keyword)

  @impl true
  def execute(asker, npc, keyword), do: dispatch(:execute, asker, npc, keyword)

  @impl true
  def effects(asker, npc, keyword), do: dispatch(:effects, asker, npc, keyword)

  defp dispatch(fn_name, asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil ->
        if fn_name == :check do
          {:error, "地藏王闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end

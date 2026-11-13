defmodule Kantele.NPC.Wuchang do
  @moduledoc """
  黑白无常 NPC 问询处理器（对应 LPC `d/death/npc/bai.c` / `hei.c` 的接引与 `ask 还阳`）。

  玩家于地府向白无常 `ask 还阳` 立即触发还阳——即 LPC `bai.c` 30 秒自动接引
  （`reincarnate()` → 落武庙）的手动版。仅当玩家处于幽灵态
  （`meta.env[:ghost] == true`）才允许，否则拒绝（阳寿未尽不该入地府）。

  还阳本体逻辑全部在 `Kantele.Character.CombatEvent.revive`（收到 `character/revive`
  事件后解除幽灵态、满状态、传送武庙、落点记 startroom）。本模块只负责在
  `ask` 命中时把该事件投递给玩家进程。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kalevala.Event

  @impl true
  def ask_specs do
    %{
      "还阳" => %{
        check: fn asker, _npc ->
          if Map.get(asker.meta.env || %{}, :ghost) == true do
            :ok
          else
            {:error, "白无常笑道：你阳寿未尽，尚不该入地府，快回去罢！\n"}
          end
        end,
        execute: fn asker, _npc ->
          if pid = asker.pid do
            send(pid, %Event{from_pid: self(), topic: "character/revive", data: %{}})
          end

          :ok
        end,
        effects: []
      }
    }
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
          {:error, "白无常闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end

defmodule Kantele.NPC.Yanluo do
  @moduledoc """
  十殿阎罗 NPC 问询处理器（对应 LPC `d/death/npc/yanluo.c`）。

  玩家向阎罗 `ask 转世` 时，阎罗判定十八层地狱已通关，置位 `HellZhenPass=1`，
  方可继续向地藏王请求转世。

  对应 LPC 流程中「十八层地狱」这一前置：玩家需先闯过十八层地狱（由阎罗确认），
  才能向地藏王发起转世生死斗。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.Records
  alias Kantele.Communication

  @impl true
  def ask_specs do
    %{
      "转世" => %{
        check: fn asker, _npc ->
          :ok
        end,
        execute: fn asker, _npc ->
          # 置位 HellZhenPass：十八层地狱已通关
          env = Map.put(asker.meta.env || %{}, :HellZhenPass, true)
          asker = %{asker | meta: %{asker.meta | env: env}}
          Records.save(asker)

          if pid = asker.pid, do:
            send(pid, {:room_message, "十殿阎罗道：你已闯过十八层地狱，可去见地藏王请求转世了。\n"})

          Communication.announce("rumor", "#{asker.name}在阎罗殿前闯过了十八层地狱，HellZhenPass已置位！")
          {:ok, asker}
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
          {:error, "十殿阎罗闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end

defmodule Kantele.NPC.Lonely do
  @moduledoc """
  高处不胜寒（lonely）NPC 问询处理器（对应 LPC `d/death/sky/npc/lonely.c`）。

  玩家向高处不胜寒 `ask 精元丹` 时，高处不胜寒发起生死斗（`NpcAttack.kill_ob/2`）。
  玩家胜后（P4-D `enemy_died` 钩子）置位 `SkyPass=1`，赠予精元丹，传送阎罗殿，
  广播江湖传闻。

  对应 LPC lonely.c：
    - accept_fight / competition_with：接受挑战
    - lost()：给予精元丹，set("SkyPass", 1)，move 玩家到 /d/death/yanluodian
    - accept_kill：requires combat_exp >= 20000000
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Communication
  alias Kantele.World.NpcActions.NpcAttack

  @impl true
  def ask_specs do
    %{
      "精元丹" => %{
        check: fn asker, _npc ->
          :ok
        end,
        execute: fn asker, npc ->
          rumor_text = "#{asker.name}向高处不胜寒请要精元丹，高处不胜寒怒而与之决一死战！"
          Communication.announce("rumor", rumor_text)

          case NpcAttack.kill_ob(npc, asker) do
            :ok ->
              if pid = asker.pid, do:
                send(pid, {:room_message, "高处不胜寒冷笑道：要精元丹？先接我几招再说！\n"})
              :ok

            {:error, _reason} ->
              {:error, "高处不胜寒似乎不愿与你交手。\n"}
          end
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
          {:error, "高处不胜寒闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end

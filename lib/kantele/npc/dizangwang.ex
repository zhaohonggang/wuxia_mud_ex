defmodule Kantele.NPC.Dizangwang do
  @moduledoc """
  地藏王 NPC 问询处理器（对应 LPC `d/death/npc/dizangwang.c` 的 `ask_zhuan` 四前置链）。

  玩家于地府向地藏王 `ask 转世` 触发转世重生。流程与 LPC `ask_zhuan` 严格对齐：

  1. `!HellZhenPass` → 拒绝（「你想转世先过了十八层地狱这一关再说！」）
  2. `SkyPass == true` → 提醒交付精元丹（「精元丹你取来了吗？取来了就快给我！」）
  3. 否则 → 发起生死斗（`NpcAttack.kill_ob/2`，双方收 `combat/start` type "kill"）

  地藏王战败（P4-C `enemy_died` 钩子）后置位 `DiZangPass=1`，传送通天门，广播江湖传闻。

  四前置（与 LPC `ask_zhuan` + 计划 D2 一致）：
    ① 大宗师（combat_exp≥800000000）
    ② 十八层地狱 `meta.env[:HellZhenPass]`
    ③ 击败地藏王 `meta.env[:DiZangPass]`
    ④ 十二重天·献精元丹 `meta.env[:SkyPass]`

  转世主体逻辑全部在 `Kantele.Character.Reborn`（`zhuan_player`）。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.Reborn
  alias Kantele.Communication
  alias Kantele.World.NpcActions.NpcAttack

  @impl true
  def ask_specs do
    %{
      "转世" => %{
        check: fn asker, _npc ->
          env = asker.meta.env || %{}
          if Map.get(env, :HellZhenPass) != true do
            {:error, "地藏王喝道：你想转世先过了十八层地狱这一关再说！\n"}
          else
            :ok
          end
        end,
        execute: fn asker, npc ->
          env = asker.meta.env || %{}
          if Map.get(env, :SkyPass) == true do
            {:error, "地藏王道：精元丹你取来了吗？取来了就快给我！\n"}
          else
            # 发起生死斗：NpcAttack.kill_ob 向双方发 combat/start (type: "kill")，
            # 对应 LPC ask_zhuan 里的 competition_with(who) + fight_ob。
            rumor_text = "#{asker.name}向地藏王请教转世，地藏王怒而与之决一死战！"
            Communication.announce("rumor", rumor_text)

            case NpcAttack.kill_ob(npc, asker) do
              :ok ->
                if pid = asker.pid, do:
                  send(pid, {:room_message, "地藏王厉声道：尔敢在老夫面前撒野，今日便让你见识见识老夫的手段！\n"})
                :ok

              {:error, _reason} ->
                {:error, "地藏王似乎不愿与你交手。\n"}
            end
          end
        end,
        effects: [{:reborn}]
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
          {:error, "地藏王闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end
end

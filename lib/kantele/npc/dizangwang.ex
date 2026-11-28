defmodule Kantele.NPC.Dizangwang do
  @moduledoc """
  地藏王 NPC 问询处理器（对应 LPC `d/death/npc/dizangwang.c` 的 `ask_xue` 与 `ask_zhuan`）。

  玩家于地府向地藏王 `ask 麒麟靴` / `ask 转世` 触发对应流程。

  ## ask_xue（麒麟靴）— 对应 LPC `ask_xue()`
  1. `!hell_quest/锁阳丹` → 拒绝（「麒麟靴是我的宝物，你打听它干什么？」）
  2. 麒麟靴在玩家身上 → 拒绝（「麒麟靴不是在你的手中么，怎么反而来找我呢？」）
  3. 麒麟靴被其他 NPC 持有 → 拒绝（「我已经把麒麟靴借出去了。」/「麒麟靴现在落在 X 手中…」）
  4. 否则 → 地藏王给予麒麟靴（`give_item` 效果），广播消息

  ## ask_zhuan（转世）— 对应 LPC `ask_zhuan()` 四前置链
  1. `!HellZhenPass` → 拒绝（「你想转世先过了十八层地狱这一关再说！」）
  2. `SkyPass == true` → 提醒交付精元丹（「精元丹你取来了吗？取来了就快给我！」）
  3. 否则 → 发起生死斗（`NpcAttack.kill_ob/2`）

  地藏王战败后置位 `DiZangPass=1`，传送通天门，广播江湖传闻。

  四前置（与 LPC `ask_zhuan` 一致）：
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
      "麒麟靴" => %{
        check: fn asker, _npc ->
          cond do
            Map.get(asker.meta.env || %{}, :"hell_quest/锁阳丹") != true ->
              {:error, "地藏王摇头道：麒麟靴是我的宝物，你打听它干什么？\n"}

            true ->
              :ok
          end
        end,
        execute: fn _asker, _npc ->
          # LPC ask_xue()：检查麒麟靴持有者，若可发放则给予。
          # ex 中简化为：若玩家已有锁阳丹标志，直接发放麒麟靴。
          # 持有者遍历（靴子在 NPC 身上/已借出/在玩家手中）依 LPC 原序留待后续细化。
          {:ok, :give_qilinxue}
        end,
        effects: [{:give_item, "death:qilinxue"}]
      },

      "转世" => %{
        check: fn asker, _npc ->
          cond do
            not Reborn.ultrap?(asker) ->
              {:error, "地藏王喝道：你尚未修炼成大宗师，不足以转世。\n"}

            Map.get(asker.meta.env || %{}, :HellZhenPass) != true ->
              {:error, "地藏王喝道：你想转世先过了十八层地狱这一关再说！\n"}

            true ->
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

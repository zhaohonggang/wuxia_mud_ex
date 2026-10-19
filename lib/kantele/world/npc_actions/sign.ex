defmodule Kantele.World.NpcActions.Sign do
  @moduledoc """
  P5-1e NPC 私有动作：`sign`（乌老大处报名屠人大赛，`d/pk/npc/wu.c`
  `do_sign()`）。

  仅注册于 `pk:entry`（屠人赛场入口，UCL `characters.wu` 经
  `room_characters "entry"` 挂入）。

  ## 移植范围（守门 + 无赛事态）

  LPC `do_sign` 的判定链：

  1. `message_vision` 打招呼（房间可见）：「$N陪着笑脸对$n道：您好，您好，
     我也来签个到。」
  2. `combat_exp < 10000` → 拒绝（房间可见）：「就你这点本事？只好参加
     被屠大赛！」
  3. `PK_D->reject_join(me)` 返回字符串 → `command("say " + msg)`。
     PK_D 是赛事状态机（STARTING / GET_READY / 报名期/经验区间判定），
     **未建模**；其 `state != GET_READY` 分支的文案「现在没要举行比赛啊？
     你跑来干什么？」即**无赛事时的既有表现**，本模块落地该态（@todo：
     PK_D 状态机接入后按状态分派）。
  4. 之后是骑马检查 / 背包携人检查 / 传送到准备室——均在 `reject_join`
     放行（GET_READY 态）后才可达，属赛事流程，@todo。

  ## 未建模依赖（@todo）

  - `PK_D->reject_join` 的四种状态文案（STARTING 的「正在举行」、经验
    低于/高于区间）随 PK_D daemon 移植时补全；`tlist[selected]` 赛事表
    （名称/经验区间）一并接入。
  - `is_riding` 骑马检查：mount 系统语义不同，待对齐。
  - `deep_inventory` 携人检查 + `me->move("/d/pk/ready")` 传送：Kantele
    背包是平铺结构（无嵌套容器），传送可走 `Teleport`，但属赛事流程内部
    步骤，随 @todo 主链路一并接上。
  """

  use Kantele.World.NpcAction

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Helpers

  @room_id "pk:entry"
  @npc_name "乌老大"
  @exp_required 10_000

  @impl true
  def run(conn, %{room_id: room_id}) when is_binary(room_id) do
    if room_id == @room_id do
      do_sign(conn)
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_sign(conn) do
    # LPC: message_vision 打招呼（无条件先行，房间可见）
    conn = Helpers.broadcast(conn, @room_id, "\n$N陪着笑脸对#{@npc_name}道：您好，您好，我也来签个到。\n")

    if exp_of(conn) < @exp_required do
      # LPC: combat_exp < 10000 → 拒绝（房间可见）
      Helpers.broadcast(conn, @room_id, "#{@npc_name}抬头看了看$N，不屑道：就你这点本事？只好参加被屠大赛！\n")
    else
      # LPC: PK_D->reject_join(me) 返回字符串 → say。
      # PK_D 未建模 → 落地其「无赛事」态文案（state != GET_READY 分支）。
      Helpers.say(conn, @room_id, @npc_name, "现在没要举行比赛啊？你跑来干什么？")
    end
  end

  defp exp_of(conn) do
    stats = (conn.character.meta || %PlayerMeta{}).stats || %Stats{}

    case stats do
      %Stats{combat_exp: value} when is_integer(value) -> value
      _ -> 0
    end
  end
end

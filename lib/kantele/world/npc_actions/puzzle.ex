defmodule Kantele.World.NpcActions.Puzzle do
  @moduledoc """
  P5-1c NPC 私有动词 `puzzle`（李瘦辞猜灯谜，`beijing:wenmiao`）。

  对应 LPC `u/mudren/npc/LiSouci.c` 的 `do_puzzle(arg)`（2022 年 mud.ren
  用 curl 调外部灯谜 API 的功能测试案例）：

  - 出题走 `external_cmd(curl, ...)` 拉 `api.jisuapi.com` 灯谜，需
    `CMD_CURL` + `AppKey` 环境；答题正确发 `GIFT_D->delay_bonus`
    （exp/pot/score）。
  - **当前部署无 curl/key**：LPC 在函数开头即
    `notify_fail("迷题还在整理中，请耐心等待开启哦。")` 后返回——玩家可见
    行为就是这一句。本移植仅实现该降级分支。

  ## @todo 未移植

  - 外部 HTTP 出题（Kantele 无 CMD_CURL 通道）。
  - `GIFT_D->delay_bonus` 奖励（成长奖励系统未建模，P2 红区）。
  """
  use Kantele.World.NpcAction

  alias Kantele.World.NpcActions.Helpers

  @impl true
  def run(conn, _params) do
    Helpers.render(conn, "迷题还在整理中，请耐心等待开启哦。\n")
  end
end

defmodule Kantele.World.NpcActions.Task do
  @moduledoc """
  P5-1d NPC 私有动作：`task`（向耶律齐覆命，`d/wuguan/npc/yelvqi.c` `do_task(arg)`）。

  仅注册于 `wuguan:guofu_dayuan2`（郭府大院，UCL `characters.yelvqi` 经
  `room_characters "guofu_dayuan2"` 挂入）。玩家先 `ask yelv qi about 工作`
  领活计，干完后 `task ok` 覆命领赏。

  ## 移植范围（守门分支）

  LPC `do_task` 的判定链：

  1. `arg != "ok"` → `return 0`：本模块同此返回 `:not_handled`，放行全局命令
     （与 yao/serve 等「拒绝即消费」不同，这里是 LPC 原样的未处理放行）。
  2. 无 `temp job_name` → 拒绝「我没给你工作，怎么跑来覆命了？」
  3. 六个完成 mark（`temp mark/劈完了` 等，LPC names 五种活计 +「挑完了」
     共六个）一个都没有 → 拒绝「我让你干的事都干完了吗？」
  4. `wuguan_job` condition 仍在期（LPC `query_condition`；Kantele 侧条件存
     session，见 `bi.ex` 惯用法）→ 拒绝「怎么这么快……」。原 LPC 在此之前还有
     一句 `command("hmm <id>)` 社交动作——emoted.c 无该 emote 定义，本代码库
     NPC handler 也无社交动作先例，跳过不移植（仅少一句房间内可见的社交反馈，
     不影响判定）。
  5. 无 `temp mark/还了`（工具未还）→ 拒绝「还是先把工具还了再说吧。」
  6. 成功：`smile` + say「干得不错，这是给你的奖赏。」+ 发银两
     （`clone/money/silver` 1+random(5) 枚）+ 加经验 50+random(20) / 潜能
     25+random(10)（潜能超上限时降为 5）+ 清 `job_name`/`mark` temp +
     记 `mark/guofu_job`。**整条被未移植系统阻塞**（@todo，见下）。

  本次只落地 2-5 四个守门分支和 6 的一句 say 文案（不发放任何奖励、不改状态，
  等奖励链路就绪后一并接上）。

  ## 未建模依赖（@todo）

  - **奖励发放**：`clone/money/silver` 无对应 item 定义（Kantele 物品库无银两
    币）；经验/潜能属 P2/P9 成长系统，`combat_exp`/`potential` 写入与
    `improve_potential` 语义未移植。成功分支暂只播 say 文案。
  - **`command("smile"/"hmm")` 社交动作**：NPC handler 无此能力（无 Helper、
    无先例），未移植。
  - **领工入口 `ask_job`**（inquiry「工作」）：下发 `job_name` 与
    `apply_condition("wuguan_job", ...)`，属普通 inquiry 层（不在本 verb 层）。
    未移植前分支 2/4 的前置状态无人写入（分支 2 恒拒绝、分支 4 恒不触发），
    与 LPC「没领工就来覆命」的行为一致。
  - 分支 4 读 session conditions（`wuguan_job` 的 Kantele 落点）；ask_job
    移植时按其实际写入位置调整读取路径。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [get_session: 2]

  alias Kantele.World.NpcActions.Helpers

  @room_id "wuguan:guofu_dayuan2"

  # LPC names = {"打扫马房", "锯木头", "劈柴", "浇菜地", "锄草"} 五种活计，
  # 完成 mark 另有不在 names 里的「挑完了」，共六个（do_task 的判全集中列全）。
  @completion_marks ~w(mark/劈完了 mark/浇完了 mark/锄完了 mark/锯完了 mark/扫完了 mark/挑完了)

  @impl true
  def run(conn, %{room_id: room_id, trailing: trailing}) when is_binary(room_id) do
    if room_id == @room_id do
      case to_string(trailing) |> String.trim() do
        "ok" -> do_task(conn)
        _ -> :not_handled
      end
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_task(conn) do
    cond do
      # LPC: if (! ob->query_temp("job_name")) —— 未领工作
      blank_temp?(conn, "job_name") ->
        Helpers.render(conn, "耶律齐皱眉道：我没给你工作，怎么跑来覆命了？\n")

      # LPC: if (! (mark/劈完了 || mark/浇完了 || ... || mark/挑完了)) —— 活没干完
      not completed_any?(conn) ->
        Helpers.render(conn, "耶律齐皱眉道：我让你干的事都干完了吗？\n")

      # LPC: if (interactive(ob) && ob->query_condition("wuguan_job")) —— 太快
      condition_active?(conn, "wuguan_job") ->
        Helpers.render(conn, "耶律齐皱眉道：怎么这么快，是不是没做完啊，吩咐你回来了吗？\n")

      # LPC: if (! ob->query_temp("mark/还了")) —— 工具未还
      blank_temp?(conn, "mark/还了") ->
        Helpers.render(conn, "耶律齐道：…嗯…你还是先把工具还了再说吧。\n")

      # @todo 成功路径（发银两 + 经验/潜能 + 清 temp + 记 mark/guofu_job）待
      # P2/P9 成长系统与银两 item 就绪后补全；暂只播 NPC 台词，不发奖励。
      true ->
        Helpers.render(conn, "耶律齐点头道：干得不错，这是给你的奖赏。\n")
    end
  end

  # LPC 真值语义：`query_temp` 未设置返回 0（假）；空串/0/false/nil 均为假
  # （与 `Helpers.flag?` 的 truthy? 一致）。
  defp blank_temp?(conn, key) do
    case Helpers.temp(conn, key) do
      nil -> true
      false -> true
      0 -> true
      "" -> true
      _ -> false
    end
  end

  defp completed_any?(conn), do: Enum.any?(@completion_marks, &present_temp?(conn, &1))

  defp present_temp?(conn, key), do: not blank_temp?(conn, key)

  # session conditions（bi.ex 惯用法）：Kantele 条件存 session 的 "conditions" map。
  # ask_job 未移植 → 无人写入 wuguan_job → 本分支当前恒不触发（@todo 见 moduledoc）。
  defp condition_active?(conn, name) do
    conds = get_session(conn, "conditions") || %{}
    truthy_condition?(Map.get(conds, name))
  end

  defp truthy_condition?(nil), do: false
  defp truthy_condition?(false), do: false
  defp truthy_condition?(0), do: false
  defp truthy_condition?(_info), do: true
end

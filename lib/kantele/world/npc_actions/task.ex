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
     （等值 1+random(5) 两白银，写入扁平 `meta.coins`）+ 加经验
     50+random(20) / 潜能 25+random(10)（走 `Stats.improve_potential/2` 封顶，
     潜能超上限时按 LPC 语义额外给 5 点）+ 清 `job_name`/`mark/还了`/完成
     mark temp + 记 `mark/guofu_job` + 落盘 `Records.save/1`。

  本次落地全部 6 个分支，包括成功路径的奖励发放与状态清理。

  ## 未建模依赖（@todo，不阻塞本 handler）

  - **`command("smile"/"hmm")` 社交动作**：NPC handler 无此能力（无 Helper、
    无先例），未移植（仅少一句房间内可见的社交反馈，不影响判定与奖励）。
  - **领工入口 `ask_job`**（inquiry「工作」）：下发 `job_name` 与
    `apply_condition("wuguan_job", ...)`，属普通 inquiry 层（不在本 verb 层）。
    未移植前分支 2/4 的前置状态无人写入（分支 2 恒拒绝、分支 4 恒不触发），
    与 LPC「没领工就来覆命」的行为一致。
  - 分支 4 读 session conditions（`wuguan_job` 的 Kantele 落点）；ask_job
    移植时按其实际写入位置调整读取路径。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [get_session: 2, put_character: 2]

  alias Kantele.Character.Stats
  alias Kantele.Economy.Money
  alias Kantele.Character.Records
  alias Kantele.World.NpcActions.Helpers

  @room_id "wuguan:guofu_dayuan2"

  # LPC names = {"打扫马房", "锯木头", "劈柴", "浇菜地", "锄草"} 五种活计，
  # 完成 mark 另有不在 names 里的「挑完了」，共六个（do_task 的判全集中列全）。
  @completion_marks ~w(mark/劈完了 mark/浇完了 mark/锄完了 mark/锯完了 mark/扫完了 mark/挑完了)

  # LPC do_task 成功段奖励字面量：银两 1+random(5) 两、经验 50+random(20)、
  # 潜能 25+random(10)（封顶，超上限降为 5）。
  @silver_count_base 1
  @silver_count_span 5        # 1 + random(5) 两白银
  @exp_base 50
  @exp_span 20                # 50 + random(20) 经验
  @pot_base 25
  @pot_span 10                # 25 + random(10) 潜能
  @pot_min_when_capped 5      # 潜能超上限时的最小发放

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

      # 成功：发银两 + 经验/潜能 + 清 temp + 记 mark/guofu_job + 落盘 + 播文案
      true ->
        conn
        |> reward()
        |> persist()
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

  # 当前生效的 character：`put_character/2` 只写 `private.update_character`，
  # 后续 helper 必须经此读取，否则会丢掉同一 handler 内先前的改动。
  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  # ---- reward：发银两 + 经验/潜能 + 清 temp + 记 mark/guofu_job ----

  # LPC do_task 成功段：银两 1+random(5) 两、经验 50+random(20)、潜能
  # 25+random(10)（封顶，超上限降为 5）。
  defp reward(conn) do
    character = current(conn)
    meta = character.meta || %{}
    stats = meta.stats || %Stats{}

    silver_count = @silver_count_base + :rand.uniform(@silver_count_span) - 1   # 1 + random(5)
    coin = silver_count * 100                                                   # 1 silver = 100 coin
    exp = @exp_base + :rand.uniform(@exp_span) - 1                              # 50 + random(20)
    pot_gain = @pot_base + :rand.uniform(@pot_span) - 1                         # 25 + random(10)

    # LPC improve_potential：封顶发放；潜能超上限时按 LPC 语义降为 5。
    after_pot = Stats.improve_potential(stats, pot_gain)
    new_stats =
      if after_pot.potential == stats.potential and pot_gain > 0 do
        # 潜能已达上限，LPC 仍给最小值 5
        Stats.add_potential(after_pot, @pot_min_when_capped)
      else
        after_pot
      end
    |> Map.put(:combat_exp, (stats.combat_exp || 0) + exp)

    # 清会话 temp：job_name、完成 mark 六个、mark/还了
    cleared_temp =
      Enum.reduce(
        ~w(job_name mark/还了) ++ @completion_marks,
        meta.temp || %{},
        &Map.delete(&2, &1)
      )

    # 记持久 mark：mark/guofu_job（落 meta.marks，随角色落盘）
    new_marks = Map.put(meta.marks || %{}, "mark/guofu_job", 1)

    conn =
      put_character(conn, %{
        character
        | meta: %{
            meta
            | stats: new_stats,
              coins: (meta.coins || 0) + coin,
              marks: new_marks,
              temp: cleared_temp
          }
      })

    conn
    |> Helpers.render("耶律齐点头道：干得不错，这是给你的奖赏。\n")
    |> then(&Helpers.render(&1, "耶律齐给你#{Money.denom_str(silver_count, "silver")}。\n"))
    |> then(&Helpers.render(&1, "你获得了#{exp}点经验和#{pot_gain}点潜能。\n"))
  end

  # 落盘 stats/coins/marks/consistence（put_character 只改内存态）。
  # 仅对真实玩家落盘：单测 fixture 的 id 为 nil，跳过可避免 Records.save/1
  # 在沙盒里刷 error 日志（同 smith.ex / peiyao.ex 惯例）。
  defp persist(conn) do
    character = current(conn)

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      Records.save(character)
    end

    conn
  end
end

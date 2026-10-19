defmodule Kantele.World.NpcActions.Jobs do
  @moduledoc """
  P5-1e NPC 私有动作：「打工类」verb 的守门家族（`copy` / `sew` / `mine` / `move`）。

  LPC 侧这四个 verb 的 handler 是同一模式的五份复制（`shutong.c` / `zhu.c` /
  `zeng.c` / `jiangong.c`×2）：先查 `is_busy`，再查对应 `job/*` 会话 temp——
  没有就走「拒绝」并消费命令，有则进入 `start_busy` 驱动的多轮干活流程
  （抄书 7 步 / 缝纫 / 搬石料 10 步，每步一条 vision，完成发经验/潜能/钱）。
  本模块只落**守门分支**，多轮干活流程 @todo（见下）。

  ## 注册（按 room_id 守门）

  | room_id | verb | NPC | 未领活时的表现 |
  |---|---|---|---|
  | `guiyun:shufang` | copy | 书童 | 广播「拜托拜托，千万别动文房四宝」 |
  | `city:shuyuan` | copy | 朱熹 | 广播「给我放下，别乱动文房四宝」 |
  | `city:garments` | sew | 曾柔 | 广播「你给我放下，有什么好玩的？」 |
  | `guanwai:shichang` | mine / move | 监工 | 「你又没领活，瞎忙活啥？」 |
  | `hangzhou:kuangshan` | mine | 监工 | 同上 |

  房间定位注意：`copy` 的两个注册分属两区——书童在 **guiyun:shufang**
  （归云庄书房），朱熹在 **city:shuyuan**（书院）；`move` 仅 guanwai 监工
  注册（`add_action("do_mine", "move")`，与 mine 同一 handler，arg 忽略）。

  ## 与 LPC 的返回语义

  shutong/zhu/zeng 的拒绝是 `message_vision`（房间可见）→ 本模块广播；
  jiangong 的拒绝是 `notify_fail`（仅本人可见）→ 本模块渲染。两者都消费
  命令（LPC 均 `return 1`）。

  ## 未建模依赖（@todo）

  - **`is_busy` 守卫**：Kantele 角色无 busy 字段（`Kalevala.Character`
    defstruct 无此项），跳过不移植——仅少一道「正忙」拦截，不影响判定链
    其余部分。
  - **多轮干活流程**（`start_busy` + `working()` 逐步 call_out）：Kantele
    无对应机制；`ask_job`（inquiry 层，未移植）是 `job/*` temp 的唯一来源，
    故「已领活」分支当前不可达，落**静默消费**（返回未改动 conn），待干活
    任务系统就绪后补 `working()` 的阶段推进与奖励。
  - 奖励发放（经验/潜能/铜钱、`mark/朱` 计数等）同属上述 @todo，届时随
    流程一并接上。
  """

  use Kantele.World.NpcAction

  alias Kantele.World.NpcActions.Helpers

  # room_id => %{job: job temp 键, mode: :broadcast/:render, text: 拒绝文案}
  # text 里的 $N 由 broadcast_vision 归一化为行动玩家（见 Helpers.broadcast/3）。
  @config %{
    "guiyun:shufang" => %{
      job: "job/copy",
      mode: :broadcast,
      text: "$N摸起毛笔，刚想蘸墨，就听见书童喊道：拜托拜托，千万别动文房四宝，我要收拾呢。\n"
    },
    "city:shuyuan" => %{
      job: "job/copy",
      mode: :broadcast,
      text: "$N摸起毛笔，刚想蘸墨，就听见朱熹大喝道：给我放下，别乱动文房四宝。\n"
    },
    "city:garments" => %{
      job: "job/sew",
      mode: :broadcast,
      text: "$N偷偷的拿起一个顶针，曾柔一声娇吒道：你给我放下，有什么好玩的？\n"
    },
    "guanwai:shichang" => %{
      job: "job/move",
      mode: :render,
      text: "你又没领活，瞎忙活啥？\n"
    },
    "hangzhou:kuangshan" => %{
      job: "job/move",
      mode: :render,
      text: "你又没领活，瞎忙活啥？\n"
    }
  }

  @impl true
  def run(conn, %{room_id: room_id}) when is_binary(room_id) do
    case Map.fetch(@config, room_id) do
      {:ok, config} -> do_job(conn, room_id, config)
      :error -> :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_job(conn, room_id, config) do
    if blank_temp?(conn, config.job) do
      refuse(conn, room_id, config)
    else
      # @todo 已领活 → LPC 走 start_busy 多轮干活；inquiry 层 ask_job 未移植，
      # 无人写 job/* temp，此分支不可达，暂静默消费（见 moduledoc）。
      conn
    end
  end

  defp refuse(conn, room_id, %{mode: :broadcast, text: text}) do
    Helpers.broadcast(conn, room_id, text)
  end

  defp refuse(conn, _room_id, %{mode: :render, text: text}) do
    Helpers.render(conn, text)
  end

  # LPC 真值语义：query_temp 未设置返回 0（假）；与 task.ex 的 blank_temp? 同规。
  defp blank_temp?(conn, key) do
    case Helpers.temp(conn, key) do
      nil -> true
      false -> true
      0 -> true
      "" -> true
      _ -> false
    end
  end
end

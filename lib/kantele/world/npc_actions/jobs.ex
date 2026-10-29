defmodule Kantele.World.NpcActions.Jobs do
  @moduledoc """
  P5-1e NPC 私有动作：「打工类」verb 的守门家族（`copy` / `sew` / `mine` / `move`）。

  LPC 侧这四个 verb 的 handler 是同一模式的五份复制（`shutong.c` / `zhu.c` /
  `zeng.c` / `jiangong.c`×2）：先查 `is_busy`，再查对应 `job/*` 会话 temp——
  没有就走「拒绝」并消费命令，有则进入 `start_busy` 驱动的多轮干活流程
  （抄书 7 步 / 缝纫 5 步 / 搬石料 10 步，每步一条 vision，完成发经验/潜能/钱）。
  本模块落**守门分支 + 多轮干活流程**（`start_busy` + 阶段推进 + 奖励结算）。

  ## 注册（按 room_id 守门）

  | room_id | verb | NPC | 总步数 | 未领活时的表现 |
  |---|---|---|---|---|
  | `guiyun:shufang` | copy | 书童 | 7 | 广播「拜托拜托，千万别动文房四宝」 |
  | `city:shuyuan` | copy | 朱熹 | 7 | 广播「给我放下，别乱动文房四宝」 |
  | `city:garments` | sew | 曾柔 | 5 | 广播「你给我放下，有什么好玩的？」 |
  | `guanwai:shichang` | mine / move | 监工 | 10 | 「你又没领活，瞎忙活啥？」 |
  | `hangzhou:kuangshan` | mine | 监工 | 10 | 同上 |

  房间定位注意：`copy` 的两个注册分属两区——书童在 **guiyun:shufang**
  （归云庄书房），朱熹在 **city:shuyuan**（书院）；`move` 仅 guanwai 监工
  注册（`add_action("do_mine", "move")`，与 mine 同一 handler，arg 忽略）。

  ## 与 LPC 的返回语义

  shutong/zhu/zeng 的拒绝是 `message_vision`（房间可见）→ 本模块广播；
  jiangong 的拒绝是 `notify_fail`（仅本人可见）→ 本模块渲染。两者都消费
  命令（LPC 均 `return 1`）。

  ## 多轮干活流程（已领活 → working()）

  已领活时（`job/*` temp 非空），每次输入 verb 推进一步：
  1. 读当前步数 temp `job/*/step`（缺省 0），自增写回；
  2. 广播/渲染第 N 步 vision（`$N` 归一化为行动玩家）；
  3. 若步数 < 总步数：`start_busy(1)`（忙乱 1 轮），提示继续干活；
  4. 若步数 >= 总步数：发奖励（经验/潜能/铜钱）、清 `job/*` 与 `job/*/step` temp、
     记 `mark/job/*` 持久计数、`Records.save/1` 落盘，播完成文案。

  奖励字面量参考 LPC `reward()`：经验 50+random(20)、潜能 25+random(10)、
  铜钱 100+random(100)（文案按 `Money.money_str/1` 显示）。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Stats
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Economy.Money
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.Character.Combat, as: KCombat

  # room_id => %{job: job temp 键, steps: 总步数, mode: :broadcast/:render,
  #   refuse_text: 未领活拒绝文案, step_text: 第 N 步 vision 模板（$N 为玩家）,
  #   finish_text: 完成文案, exp_base/exp_span, pot_base/pot_span, coin_base/coin_span,
  #   mark: 持久 mark 键}
  @config %{
    "guiyun:shufang" => %{
      job: "job/copy",
      steps: 7,
      mode: :broadcast,
      refuse_text: "$N摸起毛笔，刚想蘸墨，就听见书童喊道：拜托拜托，千万别动文房四宝，我要收拾呢。\n",
      step_text: "$N埋头抄写第 {step} 页书，笔走龙蛇。\n",
      finish_text: "书童点头道：这几页抄得不错，这是给你的工钱。\n",
      exp_base: 50, exp_span: 20,
      pot_base: 25, pot_span: 10,
      coin_base: 100, coin_span: 100,
      mark: "mark/job_copy"
    },
    "city:shuyuan" => %{
      job: "job/copy",
      steps: 7,
      mode: :broadcast,
      refuse_text: "$N摸起毛笔，刚想蘸墨，就听见朱熹大喝道：给我放下，别乱动文房四宝。\n",
      step_text: "$N在朱熹面前抄写第 {step} 页书，朱先生不时指点一二。\n",
      finish_text: "朱熹微微颔首：「这抄得工整，多承了。」\n",
      exp_base: 60, exp_span: 25,
      pot_base: 30, pot_span: 10,
      coin_base: 120, coin_span: 100,
      mark: "mark/job_copy"
    },
    "city:garments" => %{
      job: "job/sew",
      steps: 5,
      mode: :broadcast,
      refuse_text: "$N偷偷的拿起一个顶针，曾柔一声娇吒道：你给我放下，有什么好玩的？\n",
      step_text: "$N顶针一推，针线飞舞，缝补第 {step} 件衣料。\n",
      finish_text: "曾柔检看一番，笑道：「手艺不错，这是你的工钱。」\n",
      exp_base: 40, exp_span: 15,
      pot_base: 20, pot_span: 10,
      coin_base: 80, coin_span: 80,
      mark: "mark/job_sew"
    },
    "guanwai:shichang" => %{
      job: "job/move",
      steps: 10,
      mode: :render,
      refuse_text: "你又没领活，瞎忙活啥？\n",
      step_text: "$N搬起一块石料，搬运进度第 {step} 趟。\n",
      finish_text: "监工冷笑一声：「搬完了，这是你的工钱。」\n",
      exp_base: 60, exp_span: 25,
      pot_base: 30, pot_span: 15,
      coin_base: 120, coin_span: 120,
      mark: "mark/job_move"
    },
    "hangzhou:kuangshan" => %{
      job: "job/mine",
      steps: 10,
      mode: :render,
      refuse_text: "你又没领活，瞎忙活啥？\n",
      step_text: "$N挥动镐头，在第 {step} 趟采矿中。\n",
      finish_text: "监工看了看矿石，哼了一声：「凑合吧，这是你的工钱。」\n",
      exp_base: 60, exp_span: 25,
      pot_base: 30, pot_span: 15,
      coin_base: 120, coin_span: 120,
      mark: "mark/job_mine"
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
      working(conn, room_id, config)
    end
  end

  # 多轮干活：读当前步数，推进一步，广播 step vision；达总步数则结算。
  defp working(conn, room_id, config) do
    step_key = config.job <> "/step"
    step = (Helpers.temp(conn, step_key) || 0) + 1

    conn =
      conn
      |> put_temp(step_key, step)
      |> broadcast_step(room_id, config, step)

    if step >= config.steps do
      finish(conn, config, step_key)
    else
      conn
      |> start_busy(1)
      |> Helpers.render("继续干活，已经干了 #{step} 趟了。\n")
    end
  end

  defp broadcast_step(conn, room_id, config, step) do
    text = String.replace(config.step_text, "{step}", to_string(step))
    conn = case config.mode do
      :broadcast ->
        Helpers.broadcast(conn, room_id, text)
      :render ->
        Helpers.render(conn, text)
    end
    conn
  end

  defp finish(conn, config, step_key) do
    character = current(conn)
    meta = character.meta || %{}
    stats = meta.stats || %Stats{}

    exp = config.exp_base + :rand.uniform(config.exp_span) - 1
    pot = config.pot_base + :rand.uniform(config.pot_span) - 1
    coin = config.coin_base + :rand.uniform(config.coin_span) - 1

    # LPC improve_potential：封顶发放
    new_stats =
      stats
      |> Map.put(:combat_exp, (stats.combat_exp || 0) + exp)
      |> Stats.improve_potential(pot)

    job_count = (meta.marks || %{})[config.mark] || 0

    # 清会话 temp：job/* 与 job/*/step
    cleared_temp =
      Enum.reduce([config.job, step_key], meta.temp || %{}, &Map.delete(&2, &1))

    # 记持久 mark：计数 +1（落 meta.marks，随角色落盘）
    new_marks = Map.put(meta.marks || %{}, config.mark, job_count + 1)

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
    |> Helpers.render(config.finish_text)
    |> then(&Helpers.render(&1, "你获得了#{exp}点经验和#{pot}点潜能。\n"))
    |> then(&Helpers.render(&1, "拿到#{Money.money_str(coin)}。\n"))
    |> persist()
  end

  defp refuse(conn, room_id, %{mode: :broadcast, refuse_text: text}) do
    Helpers.broadcast(conn, room_id, text)
  end

  defp refuse(conn, _room_id, %{mode: :render, refuse_text: text}) do
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

  # 当前生效的 character：`put_character/2` 只写 `private.update_character`，
  # 后续 helper 必须经此读取，否则会丢掉同一 handler 内先前的改动。
  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp put_temp(conn, key, value) do
    character = current(conn)
    meta = PlayerMeta.put_temp(character.meta, key, value)
    put_character(conn, %{character | meta: meta})
  end

  defp start_busy(conn, rounds) do
    character = current(conn)
    combat = KCombat.start_busy(character.meta.combat || KCombat.new(), rounds)
    put_character(conn, %{character | meta: %{character.meta | combat: combat}})
  end

  # 落盘 stats/coins/marks（put_character 只改内存态）。
  # 仅对真实玩家落盘：单测 fixture 的 id 为 nil，跳过可避免 Records.save/1
  # 在沙盒里刷 error 日志（同 task.ex / smith.ex 惯例）。
  defp persist(conn) do
    character = current(conn)

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      Records.save(character)
    end

    conn
  end
end
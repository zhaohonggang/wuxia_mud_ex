defmodule Kantele.World.InquiryHandlers.SmithJob do
  @moduledoc """
  襄阳铁匠（`xiangyang:tiejiangpu`）的派活问询（kind = "smith_job"）。

  LPC 源：`/inherit/char/smith.c` 的 `ask_me()`（`d/xiangyang/npc/smith.c`
  以 `(: ask_me :)` 绑 inquiry「job」/「工作」）。玩家 `ask tiejiang about job`
  命中本 kind，NPC 侧 `NpcAskEvent` 把 kind/config 回执到玩家进程，由本模块
  落会话 temp 并回话。

  ## 判定链（LPC ask_me 原序）

  1. `mark/job_smith > 10000` → 「您老不会真想做一辈子的铁匠吧？」
     （`mark/*` 持久，读 `meta.marks`；由 `NpcActions.Smith` 的 reward 累加）
  2. `qi < 50` → 「你还是歇会儿吧！要是出了人命我可承担不起。」
  3. 已派 `smith/gu` → 「让你去鼓(gu)一会儿风箱，你怎么还磨蹭？」
  4. 已派 `smith/dapi` → 「叫你打的坯(dapi)你打了没有？」
  5. 已派 `smith/cuihuo` → 「干活怎么尽偷懒？快给我淬火(cuihuo)去！」
  6. `random(3)` 三选一派活：写 `meta.temp["smith/gu|dapi|cuihuo"] = 1`
     并回对应任务文案。会话 temp 由同房间 `gu` / `dapi` / `cuihuo`
     （`Kantele.World.NpcActions.Smith`）消费，完成后 reward 清零。

  ## 与 LPC 的差异

  - LPC 颜色宏（HIY/CYN）已剥离，仅保留文案。
  - temp 是会话级（`meta.temp`，不落盘）—— 与 LPC `query_temp`/
    `set_temp` 一致；`mark/job_smith` 持久（`meta.marks`，随角色落盘）。
  - 回话经 `Kalevala.Character.Conn.render`（CommandView）推送，仅问者可见
    （LPC 返回值即 tell_object 语义，无 message_vision）。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.World.NpcActions.Helpers

  # LPC ask_me 字面量
  @job_count_limit 10_000
  @min_qi 50

  def run(conn, _config, %{asker_id: asker_id}) do
    character = current(conn)

    case asker_id == character.id do
      false -> conn
      true -> ask_me(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  defp ask_me(conn, character) do
    meta = character.meta || %{}
    vitals = meta.vitals
    marks = meta.marks || %{}
    temp = meta.temp || %{}

    job_count = Map.get(marks, "mark/job_smith") || 0
    qi = if vitals, do: Map.get(vitals, :qi) || 0, else: 0

    cond do
      # LPC: if (me->query("mark/job_smith") > 10000)
      job_count > @job_count_limit ->
        reply(conn, "您老不会真想做一辈子的铁匠吧？")

      # LPC: if (me->query("qi") < 50)
      qi < @min_qi ->
        reply(conn, "你还是歇会儿吧！要是出了人命我可承担不起。")

      # LPC: if (me->query_temp("smith/gu"))
      present_temp?(temp, "smith/gu") ->
        reply(conn, "让你去鼓(gu)一会儿风箱，你怎么还磨蹭？")

      # LPC: if (me->query_temp("smith/dapi"))
      present_temp?(temp, "smith/dapi") ->
        reply(conn, "叫你打的坯(dapi)你打了没有？")

      # LPC: if (me->query_temp("smith/cuihuo"))
      present_temp?(temp, "smith/cuihuo") ->
        reply(conn, "干活怎么尽偷懒？快给我淬火(cuihuo)去！")

      # LPC: switch (random(3)) —— 派活并写会话 temp
      true ->
        assign_job(conn)
    end
  end

  # LPC random(3)：0=gu / 1=dapi / 2=cuihuo
  defp assign_job(conn) do
    case :rand.uniform(3) do
      1 ->
        conn
        |> Helpers.put_temp("smith/gu", 1)
        |> reply("好！你帮我鼓(gu)一会儿风箱。")

      2 ->
        conn
        |> Helpers.put_temp("smith/dapi", 1)
        |> reply("这样吧，你帮我打(dapi)一下坯吧！")

      3 ->
        conn
        |> Helpers.put_temp("smith/cuihuo", 1)
        |> reply("去帮我把这些刚出炉的淬(cuihuo)一下火。")
    end
  end

  # LPC 真值语义：query_temp 未设置返回 0（假）
  defp present_temp?(temp, key) do
    case Map.get(temp, key) do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

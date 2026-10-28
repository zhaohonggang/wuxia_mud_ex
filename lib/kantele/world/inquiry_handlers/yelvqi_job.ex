defmodule Kantele.World.InquiryHandlers.YelvqiJob do
  @moduledoc """
  郭府大院耶律齐的领活计问询（kind = "yelvqi_job"）。

  LPC 源：`/d/wuguan/npc/yelvqi.c` 的 `ask_job()`（玩家 `ask yelv qi about 工作`
  命中本 kind，NPC 侧 `NpcAskEvent` 把 kind/config 回执到玩家进程，由本模块
  落会话 temp 并回话）。

  ## 判定链（LPC ask_job 原序）

  1. `query_temp("job_name")` 已领活 → 「你不是已经领了工作吗？还不快去做。」
  2. `query("combat_exp") >= 40000` 功夫够高 →
     「你功夫已经足够闯荡江湖，这里没有什么适合你的工作了。」
  3. `query("mark/guofu_out")` 已外出 → 「你不是已经外出闯荡了吗，怎么又回来了？」
  4. 随机选一种活计（`names = 打扫马房/锯木头/劈柴/浇菜地/锄草`），写
     `temp job_name = 目标活计` 并 `apply_condition("wuguan_job", random(3)+4)`，
     回「…嗯…你先到物品房领工具，然后去后院「<target>」吧。」

  `job_name` / `wuguan_job` 的落点是 `Kantele.World.NpcActions.Task`（`task ok`
  覆命）分支 2 / 4 的前置状态，本模块补足后覆命链路方可联通。

  ## 与 LPC 的差异

  - LPC 颜色宏（HIY/CYN）已剥离，仅保留文案。
  - `job_name` 写会话 temp（`meta.temp`，不落盘），与 LPC `set_temp` 一致。
  - `wuguan_job` 走 `ConditionEvent.grant` 写入 session.conditions（计时 condition，
    见 `Kantele.WuguanJob`），对应 LPC `apply_condition`；时限 4-6s（引擎心跳 1s）。
  - `mark/guofu_out` 读会话 temp（同 `Kantele.World.NpcActions.Task` 读 `mark/*`
    完成标记的约定），当前端口无人写入该 mark，此分支恒不触发（与 LPC「没外出却
    回来」的语义一致，属死分支）。
  - 回话经 `CommandView` 推送，仅问者可见。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kalevala.Character.Conn
  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Helpers

  # LPC: string *names = ({"打扫马房", "锯木头", "劈柴", "浇菜地", "锄草" });
  @job_names ~w(打扫马房 锯木头 劈柴 浇菜地 锄草)
  # LPC: apply_condition("wuguan_job", random(3) + 4) → 4..6（:rand.uniform(3) = 1..3）
  @job_duration_span 3
  @job_duration_base 3

  def run(conn, _config, %{asker_id: asker_id}) do
    character = current(conn)

    case asker_id == character.id do
      false -> conn
      true -> ask_job(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  defp ask_job(conn, character) do
    meta = character.meta || %PlayerMeta{}
    temp = meta.temp || %{}
    stats = meta.stats
    combat_exp = if stats, do: stats.combat_exp || 0, else: 0

    cond do
      # LPC: if (ob->query_temp("job_name"))
      present_temp?(temp, "job_name") ->
        reply(conn, "你不是已经领了工作吗？还不快去做。")

      # LPC: if (ob->query("combat_exp") >= 40000)
      combat_exp >= 40_000 ->
        reply(conn, "你功夫已经足够闯荡江湖，这里没有什么适合你的工作了。")

      # LPC: if (ob->query("mark/guofu_out"))
      present_temp?(temp, "mark/guofu_out") ->
        reply(conn, "你不是已经外出闯荡了吗，怎么又回来了？")

      # LPC: 随机选活计 + 派活
      true ->
        assign_job(conn)
    end
  end

  # LPC: target = names[random(sizeof(names))];
  #      set_temp("job_name", target);
  #      apply_condition("wuguan_job", random(3) + 4);
  #      return "…嗯…你先到物品房领工具，然后去后院「<target>」吧。\n";
  defp assign_job(conn) do
    target = Enum.random(@job_names)
    duration = :rand.uniform(@job_duration_span) + @job_duration_base

    conn
    |> Helpers.put_temp("job_name", target)
    |> ConditionEvent.grant("wuguan_job", %{"duration" => duration})
    |> reply("…嗯…你先到物品房领工具，然后去后院「#{target}」吧。")
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

  defp current(%Conn{character: character}), do: character
end

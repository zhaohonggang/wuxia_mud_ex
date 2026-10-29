defmodule Kantele.World.InquiryHandlers.JobsJob do
  @moduledoc """
  打工类 NPC 的领活问询（kind = "jobs_job"）。

  玩家向书童/朱熹/曾柔/监工询问工作，本模块检查是否已有 job/* temp，
  没有则写入对应的 job/* temp，让后续 `Kantele.World.NpcActions.Jobs`
  守门分支进入多轮干活流程。

  ## 判定链

  1. `asker_id != character.id` → 静默忽略（不是问询者本人）
  2. 当前房间不在 `@room_jobs` 里 → 「这里没有可领的工作。」
  3. 已有对应 job/* temp → 「你不是已经领了工作吗？还不快去做。」
  4. 否则 → 写 `temp[job/*] = 1`，回领活文案

  ## 与 LPC 的差异

  - LPC 各 NPC 的 `ask_job()` 分散在 `shutong.c` / `zhu.c` / `zeng.c` /
    `jiangong.c`，本模块合并为一个 kind（按 `character.room_id` 分流）。
  - job/* 写会话 temp（`meta.temp`，不落盘），与 LPC `set_temp` 一致。
  - 回话经 `CommandView` 推送，仅问者可见。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kalevala.Character.Conn
  alias Kantele.Character.CommandView
  alias Kantele.World.NpcActions.Helpers

  # room_id => job temp 键（与 Kantele.World.NpcActions.Jobs @config 的 job 字段一致）
  @room_jobs %{
    "guiyun:shufang" => "job/copy",
    "city:shuyuan" => "job/copy",
    "city:garments" => "job/sew",
    "guanwai:shichang" => "job/move",
    "hangzhou:kuangshan" => "job/mine",
  }

  @assign_texts %{
    "guiyun:shufang" => "…嗯…你先到文房四宝前开始抄书吧。\n",
    "city:shuyuan" => "好，你去朱熹面前抄书。\n",
    "city:garments" => "好，你去曾柔那里缝补衣料。\n",
    "guanwai:shichang" => "去搬运石料吧。\n",
    "hangzhou:kuangshan" => "去采矿吧。\n"
  }

  def run(conn, _config, %{asker_id: asker_id}) do
    character = current(conn)

    case asker_id == character.id do
      false -> conn
      true -> ask_job(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  defp ask_job(conn, character) do
    meta = character.meta || %{}
    temp = meta.temp || %{}
    room_id = character.room_id

    job_key = Map.get(@room_jobs, room_id)

    cond do
      job_key == nil ->
        reply(conn, "这里没有可领的工作。")

      present_temp?(temp, job_key) ->
        reply(conn, "你不是已经领了工作吗？还不快去做。")

      true ->
        conn
        |> Helpers.put_temp(job_key, 1)
        |> reply(Map.get(@assign_texts, room_id))
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
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

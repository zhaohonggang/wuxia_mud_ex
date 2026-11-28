defmodule Kantele.NPC.CityPing do
  @moduledoc """
  平一指 NPC 问询处理器（对应 LPC `d/city/npc/ping.c` 的 `ask_job()`）。

  玩家向平一指 `ask 平一指 about 配药`（或别名 `工作` / `job`）触发配药入口：

  1. `temp job/peiyao` 已设 → 拒绝：「让你干的活你干完了么？」
  2. `combat_exp > 20000` 且 `mark/job_peiyao > 1000` → 拒绝：「让你干这活，也太屈就你了吧。」
  3. `combat_exp < 5000` → 拒绝：「就凭你就这点能力，我看你来药臼都端不起来！」
  4. `qi < 5` → 拒绝：「你还是先歇歇吧，万一累出人命来我可负担不起。」
  5. 否则 → 设 `temp job/peiyao = 1`，提示：「好，你就帮我配药(peiyao)吧！喏，就这几味。」

  实际配药（qi -1、经验/潜能 +30~49、mark/job_peiyao +1、结算铜钱）已在
  `Kantele.World.NpcActions.Peiyao`（`peiyao` 动词）中实现；本处理器只负责
  `ask_job` 守门与领活标志设置，不重复 `peiyao.ex` 的结算逻辑。

  LPC 原序：① 已领活 → ② 富裕/高经验 → ③ 经验不足 → ④ 气不足 → ⑤ set_temp + 提示。

  已知差异：LPC `ask_job()` 还有一道 `interactive(me)` 守门（非玩家自动问询返回
  "……"），AskCommand 尚未建模，故此处暂不实现该门；如后续接入 AskCommand，
  可在 check/3 里补 `asker.pid` 为 nil 时返回 "……"。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.PlayerMeta

  @keywords ["配药", "工作", "job"]

  @weak_exp_threshold 5_000
  @rich_exp_threshold 20_000
  @rich_job_count 1000
  @min_qi 5

  @impl true
  def ask_specs do
    Map.new(@keywords, fn keyword ->
      {keyword,
       %{
         check: fn asker, _npc -> check(asker, keyword) end,
         execute: fn asker, _npc -> execute(asker, keyword) end,
         effects: []
       }}
    end)
  end

  @impl true
  def check(asker, _npc, keyword), do: check(asker, keyword)

  @impl true
  def execute(asker, _npc, keyword), do: execute(asker, keyword)

  @impl true
  def effects(_asker, _npc, _keyword), do: []

  # ---- check ----

  defp check(asker, keyword) do
    cond do
      keyword not in @keywords ->
        {:error, "平一指闭目不语。\n"}

      job_pending?(asker) ->
        {:error, "让你干的活你干完了么？\n"}

      too_rich?(asker) ->
        {:error, "让你干这活，也太屈就你了吧。\n"}

      too_weak?(asker) ->
        {:error, "就凭你就这点能力，我看你来药臼都端不起来！\n"}

      too_low_qi?(asker) ->
        {:error, "你还是先歇歇吧，万一累出人命来我可负担不起。\n"}

      true ->
        :ok
    end
  end

  # ---- execute ----

  defp execute(asker, keyword) do
    cond do
      keyword not in @keywords ->
        {:error, "平一指闭目不语。\n"}

      job_pending?(asker) ->
        {:error, "让你干的活你干完了么？\n"}

      too_rich?(asker) ->
        {:error, "让你干这活，也太屈就你了吧。\n"}

      too_weak?(asker) ->
        {:error, "就凭你就这点能力，我看你来药臼都端不起来！\n"}

      too_low_qi?(asker) ->
        {:error, "你还是先歇歇吧，万一累出人命来我可负担不起。\n"}

      true ->
        # LPC ask_job()：set_temp("job/peiyao", 1)
        character =
          asker
          |> put_temp("job/peiyao", 1)

        {:ok, "好，你就帮我配药(peiyao)吧！喏，就这几味。\n", character}
    end
  end

  # ---- guards ----

  defp job_pending?(%{meta: %{temp: temp}}) when is_map(temp),
    do: Map.get(temp, "job/peiyao") not in [nil, false]
  defp job_pending?(_), do: false

  defp too_rich?(%{meta: %{stats: stats, marks: marks}}) when is_map(stats) and is_map(marks) do
    combat_exp = Map.get(stats, :combat_exp, 0) || 0
    job_count = Map.get(marks, "job/peiyao", 0) || 0
    combat_exp > @rich_exp_threshold and job_count > @rich_job_count
  end
  defp too_rich?(_), do: false

  defp too_weak?(%{meta: %{stats: stats}}) when is_map(stats) do
    (Map.get(stats, :combat_exp, 0) || 0) < @weak_exp_threshold
  end
  defp too_weak?(_), do: false

  defp too_low_qi?(%{meta: %{vitals: vitals}}) when is_map(vitals) do
    (Map.get(vitals, :qi, 0) || 0) < @min_qi
  end
  defp too_low_qi?(_), do: false

  # ---- helpers ----

  defp put_temp(character, key, value) do
    meta = PlayerMeta.put_temp(character.meta, key, value)
    %{character | meta: meta}
  end
end

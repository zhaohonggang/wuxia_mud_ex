defmodule Kantele.World.RoomActions.Hengyang.Liufugate.Push do
  @moduledoc """
  `d/hengyang/liufugate.c` 的 `do_push`（LPC 目标词 `gate`）。

  - 玩家未带 `marks` 临时标记 → 提示「门关得牢牢的，急切打不开！」（LPC 先查 marks）
  - 参数非 `gate` → :not_handled（放行全局 push）
  - 否则开 enter→hengyang:liufudayuan、播报、5 秒后自关。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @opened "$N走到门前，把门随便一推，居然就推开了大门！\n"
  @locked "门关得牢牢的，急切打不开！\n"
  @closed "大门又缓缓地关上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    char = Push.current(conn)
    arg = String.trim(arg)

    cond do
      not has_marks?(char) ->
        Push.render(conn, @locked)

      arg != "gate" ->
        :not_handled

      true ->
        Push.reveal(conn, room_id, "enter", "hengyang:liufudayuan", @opened,
          [{room_id, "enter", @closed}], 5)
    end
  end

  @doc """
  玩家是否已带 marks 标记（LPC `me->query_temp("marks")`）。

  LPC 里 `set_temp("marks/liufu", 1)` 建的是 **marks 映射**，`query_temp("marks")`
  返回整个映射——只要映射非空即为真。引擎侧 `marks/<key>` 按扁平键存
  （同 `player_temp_branch`），因此这里判定「任一 `marks/` 前缀键存在」。

  P5-6 修正：此前只读扁平键 `"marks"`，而语料里没有任何地方写它（knock 写的
  是 `marks/liufu`）→ 门永远打不开；补齐 `do_knock` 后此判定才与 LPC 对齐。
  """
  def has_marks?(%{meta: %{temp: temp}}) when is_map(temp) do
    Enum.any?(temp, fn {key, value} ->
      String.starts_with?(key, "marks/") and value not in [nil, false]
    end)
  end

  def has_marks?(_char), do: false
end

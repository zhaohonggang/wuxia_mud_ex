defmodule Kantele.World.RoomActions.Hengyang.Liufugate.Push do
  @moduledoc """
  `d/hengyang/liufugate.c` 的 `do_push`（LPC 目标词 `gate`）。

  - 玩家未带 `marks` 临时标记 → 提示「门关得牢牢的，急切打不开！」（LPC 先查 marks）
  - 参数非 `gate` → :not_handled（放行全局 push）
  - 否则开 enter→hengyang:liufudayuan、播报、5 秒后自关。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @room_id "hengyang:liufugate"
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

  defp has_marks?(%{meta: %{temp: temp}}) when is_map(temp),
    do: Map.get(temp, "marks") != nil and Map.get(temp, "marks") != false

  defp has_marks?(_char), do: false
end

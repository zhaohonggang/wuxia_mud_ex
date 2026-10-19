defmodule Kantele.World.NpcActions.Serve do
  @moduledoc """
  P5-1c NPC 私有动词 `serve`（向厨师要吃的）。

  对应 LPC `d/meizhuang/npc/chushi.c` 与 `d/wuguan/npc/chushi.c` 的
  `do_serve()`——两份实现逐字相同，仅 NPC 所在房间不同，故复用一份
  handler，注册于：

  - `meizhuang:chufang`（梅庄厨房）
  - `wuguan:guofu_fanting`（郭府饭厅）

  ## 语义

  - 玩家身上同时有饭(`rice`)和茶(`tea`) → notify_fail「你身上不是还有么？」
  - 房间地上同时有饭和茶 → notify_fail「这周围不是还有么？」
  - 否则 message_vision「厨师将热气腾腾的饭菜递到$N手中」并发饭 + 茶各一件。

  与 `Yao` 同约定：LPC `notify_fail` 渲染提示后即消耗本次输入（无同名
  二次命令，不会再落到默认「什么？」）。
  """
  use Kantele.World.NpcAction

  alias Kantele.World.NpcActions.Helpers

  # LPC `new("/d/wuguan/obj/rice")` / `new("/d/wuguan/obj/tea")`
  @rice "wuguan:rice"
  @tea "wuguan:tea"

  @impl true
  def run(conn, %{room_id: room_id}) do
    if is_binary(room_id) and room_id != "" do
      do_serve(conn, room_id)
    else
      :not_handled
    end
  end

  defp do_serve(conn, room_id) do
    character = conn.character

    cond do
      # LPC present("rice", me) && present("tea", me)
      Helpers.carries?(character, "rice") and Helpers.carries?(character, "tea") ->
        Helpers.render(conn, "厨师道：你身上不是还有么？吃完了再拿，别浪费食物。\n")

      # LPC present("rice", environment(me)) && present("tea", environment(me))
      Helpers.room_has_item?(room_id, "rice") and Helpers.room_has_item?(room_id, "tea") ->
        Helpers.render(conn, "厨师道：这周围不是还有么？吃完了再拿，别浪费食物。\n")

      true ->
        conn
        |> Helpers.broadcast(room_id, "\n厨师将热气腾腾的饭菜递到$N手中，笑道：你慢用。\n\n")
        |> Helpers.give_item(@rice)
        |> Helpers.give_item(@tea)
    end
  end
end

defmodule Kantele.World.RoomActions.Chengdu.Eastroad3.Break do
  @moduledoc """
  `d/chengdu/eastroad3.c` 的 `do_break`（LPC 目标词 `liang`）。

  - 参数非 `liang` → `return 0`（无 notify_fail）→ `:not_handled`（交还全局命令，
    玩家看到默认「什么？」）。
  - 已开（`query("break")`）→ 提示「房梁已经被震飞，用不着再费力了。」
  - 最大内力 < 1000 → 播报内力不济被反震、内力清零 + 昏厥。
  - 否则 → 开 enter→chengdu:minju、内力清零、set break=1（**无自动关门**，
    LPC 没有 `close()` 回调，破开即永久生效）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "liang" do
      :not_handled
    else
      if Break.open?(room_id, "enter") do
        Helpers.render_to_player(conn, "房梁已经被震飞，用不着再费力了。\n")
      else
        conn = Break.broadcast(conn, room_id, "$N走到房前，运气双掌，猛地击向垮塌的房梁！\n")

        if Break.max_neili(Break.current(conn)) < 1000 do
          conn
          |> Break.broadcast(room_id, "结果只听一声闷哼，$N内力不济，被房梁反震，眼前顿时一黑……\n")
          |> Break.pass_out()
        else
          conn
          |> Break.broadcast(room_id, "只听一声轰响，房梁顿时被$N震得飞起，露出了大门！\n")
          |> DynamicExit.open(room_id, "enter", "chengdu:minju", "")
          |> Break.set_neili(0)
        end
      end
    end
  end
end

defmodule Kantele.World.RoomActions.Fuzhou.Houyuan.Break do
  @moduledoc """
  `d/fuzhou/houyuan.c` 的 `do_break`（LPC 目标词 `men`）。

  - 已开（`query("break")`）→ 提示「大门已经被震开，用不着再费力了。」
  - 参数非 `men` → 提示「什么？」
  - 内力 ≥ 200 → 开 south→fuzhou:laozhai、扣 200、5 秒后自动关（`close()` 播
    「门上的砖头瓦块…坍塌…」）。
  - 内力不足 → 内力清零 + 播报灰尘飞扬（LPC 不昏厥）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if Break.open?(room_id, "south") do
      Helpers.render_to_player(conn, "大门已经被震开，用不着再费力了。\n")
    else
      if String.trim(arg) != "men" do
        Helpers.render_to_player(conn, "什么？\n")
      else
        conn = Break.broadcast(conn, room_id, "$N走到后门前，拜出骑马蹲裆式，深吸一口气，双掌同时拍出。\n")

        if Break.neili(Break.current(conn)) >= 200 do
          conn
          |> Break.broadcast(room_id, "只听轰然一声巨响，$N把门给震开了。\n")
          |> Break.reveal(room_id, "south", "fuzhou:laozhai", "",
            {5, "门上的砖头瓦块稀里花拉坍塌下来，又挡住了小门。\n"}
          )
          |> Break.deduct_neili(200)
        else
          conn
          |> Break.broadcast(room_id,
            "$N大吼一声“开！”，双掌同时向门拍去。\n结果大门被震得砰的一声，灰尘四处飞扬。\n"
          )
          |> Break.set_neili(0)
        end
      end
    end
  end
end

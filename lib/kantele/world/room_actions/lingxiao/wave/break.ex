defmodule Kantele.World.RoomActions.Lingxiao.Wave.Break do
  @moduledoc """
  `d/lingxiao/wave.c` 的 `do_break`（无需参数）。

  - 内力 < 2000 → 内力清零 + 昏厥（被冰壁寒气回侵经脉）。
  - 否则 → 开 enter→lingxiao:yudong、内力清零、5 秒后自动关（寒气冻严）。
  - 注：`valid_leave`（玄冰赤蟒封路）属移动限制，不在本批 `do_break` 移植范围。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break

  @impl true
  def run(conn, %{room_id: room_id}) do
    conn = Break.broadcast(conn, room_id, "$N走到冰壁前，运劲向冰壁轰去！\n")

    if Break.neili(Break.current(conn)) < 2000 do
      conn
      |> Break.broadcast(room_id, "结果只听一声闷哼，$N被冰壁的寒气回侵经脉，眼前一黑……\n")
      |> Break.pass_out()
    else
      conn
      |> Break.broadcast(room_id, "$N只听一声轰响，冰壁被轰穿了，露出一个小洞来。\n")
      |> Break.reveal(room_id, "enter", "lingxiao:yudong", "",
        {5, "一股寒气自洞中冒出，将洞口又冻了个严严实实。\n"}
      )
      |> Break.set_neili(0)
    end
  end
end

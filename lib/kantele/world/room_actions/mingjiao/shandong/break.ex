defmodule Kantele.World.RoomActions.Mingjiao.Shandong.Break do
  @moduledoc """
  `d/mingjiao/shandong.c` 的 `do_break`（LPC 目标词 `men`）。

  - 参数非 `men` → 提示「你在干吗? 」
  - 内力 < 2000 → 提示「你运了运气，觉得自己现在的内力不济。」（**不改内力、不昏厥**）。
  - 扣 2000 后若武力 < 300 → 播报「没什么动静」+ 私发「内功火候还不够」，**不开门**。
  - 否则 → 开 enter→mingjiao:midao0、再扣 400、5 秒后自动关（石门缓缓闭上）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "men" do
      Helpers.render_to_player(conn, "你在干吗? \n")
    else
      if Break.neili(Break.current(conn)) < 2000 do
        Helpers.render_to_player(conn, "你运了运气，觉得自己现在的内力不济。\n")
      else
        conn = Break.deduct_neili(conn, 2000)

        if Break.force_level(Break.current(conn)) < 300 do
          conn
          |> Break.broadcast(room_id, "$N呀呀嘿嘿废了半天力气，结果没什么动静。\n")
          |> Break.render("看来是自己的内功火候还不够。\n")
        else
          conn
          |> Break.broadcast(room_id, "石门在$N一击之下轧轧声响，缓缓移开。\n")
          |> Break.reveal(room_id, "enter", "mingjiao:midao0", "",
            {5, "石门又在轧轧声响，缓缓闭上。\n"}
          )
          |> Break.deduct_neili(400)
        end
      end
    end
  end
end

defmodule Kantele.World.RoomActions.Wanjiegu.Entrance.Push do
  @moduledoc """
  `d/wanjiegu/entrance.c` 的 `do_push`（LPC 目标词 `草丛`/`grass`）。

  - 参数为空或非 `草丛`/`grass` → :not_handled（放行全局 push）
  - 否则开 enter→wanjiegu:tree_hole、播报、10 秒后自关。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @room_id "wanjiegu:entrance"
  @args ["草丛", "grass"]
  @opened "$N拨开长草，树上出现一洞。\n"
  @closed "长草又合拢了，把树洞遮没。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    if arg in @args do
      Push.reveal(conn, room_id, "enter", "wanjiegu:tree_hole", @opened,
        [{room_id, "enter", @closed}], 10)
    else
      :not_handled
    end
  end
end

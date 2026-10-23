defmodule Kantele.World.RoomActions.Foshan.PmRestroom.Close do
  @moduledoc """
  `d/foshan/pm_restroom.c` 的 `do_close`（管理员关门，与 `Open` 成对）。

  LPC 原文：

      int do_close()
      {
              object me = this_player();

              if (! query("exits/south"))
                      return notify_fail("门已经是关着的了。\\n");

              delete("exits/south");
              message_vision(WHT "$N" WHT "顺手一带，将通向拍卖后厅的"
                             "小门关上了。\\n" NOR, me);
              return 1;
      }

  与 `Open` 同样只对 `wiz_level >= 3` 生效（LPC 在 `init()` 里一起
  `add_action`）；普通玩家返回 `:not_handled`，交回全局 `CloseCommand`。

  `delete("exits/south")` 在 `message_vision` **之前**（与 `Open` 相反），
  顺序不影响可见结果：删除出口不会改变在场玩家的输出顺序。
  """
  use Kantele.World.RoomAction

  alias Kantele.Admin.Access
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @required_wiz_level 3
  @closed "$N顺手一带，将通向拍卖后厅的小门关上了。\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    case Map.get(conn, :character) do
      %{} = character when is_binary(room_id) ->
        if Access.has_level?(character, @required_wiz_level) do
          close_door(conn, room_id)
        else
          :not_handled
        end

      _ ->
        :not_handled
    end
  end

  defp close_door(conn, room_id) do
    if DynamicExit.open?(room_id, "south") do
      DynamicExit.close(conn, room_id, "south", @closed)
    else
      Helpers.render_to_player(conn, "门已经是关着的了。\n")
    end
  end
end

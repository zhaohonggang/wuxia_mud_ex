defmodule Kantele.World.RoomActions.Gumu.Mishi1.Zhan do
  @moduledoc """
  古墓密室（`d/gumu/mishi1.c`）的 `do_zhan`（`add_action("do_zhan","zhan")`）。

  粘砖开门：`zhan brick`，须先 `ci brick` 探过空（`tmarks/砖 >= 1`，见 `Ci`）。
  开 `down`→`gumu:houting`，5 秒后落砖自动遮住；用完把 `tmarks/砖` 归零
  （想再开得再刺一次）。

  LPC 原文：

      if (!arg || arg != "brick" || me->query_temp("tmarks/砖",1) < 1)
          return notify_fail("你要粘住什么？\\n");
      message_sort("$N双手紧贴青砖，使个‘粘’字诀，轻轻巧巧地将这块青砖粘了出来。"
                   "如此没粘到几块砖，墙壁上就现出了一个大洞。\\n", me);
      set("exits/down", __DIR__"houting");
      remove_call_out("close"); call_out("close", 5);
      me->set_temp("tmarks/砖", 0);

  `query_temp(key, raw)` 的第二参是 `raw` 标志而非默认值（见
  `mudcore/inherit/dbase.c`），未设时返回 0 → 门槛判定按「未设即不通过」。
  `close(object room)` 回调无守卫，故 `only_if_open: false`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Trigger

  @self_room "gumu:mishi1"
  @target_room "gumu:houting"
  @dir "down"
  @mark_key "tmarks/砖"
  @close_seconds 5

  @what "你要粘住什么？\n"
  @stuck "$N双手紧贴青砖，使个‘粘’字诀，轻轻巧巧地将这块青砖粘了出来。如此没粘到几块砖，墙壁上就现出了一个大洞。\n"
  @close_msg "\n过不多一会儿，梁上落下几块青砖，又将墙上的洞遮住了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    if String.trim(arg) != "brick" or Trigger.temp(conn, @mark_key, 0) < 1 do
      Trigger.render(conn, @what)
    else
      stick(conn)
    end
  end

  defp stick(conn) do
    conn
    |> Trigger.put_temp(@mark_key, 0)
    |> Trigger.reveal(@self_room, @dir, @target_room, @stuck, @close_msg, @close_seconds)
  end
end

defmodule Kantele.World.RoomActions.Gumu.Mishi1.Ci do
  @moduledoc """
  古墓密室（`d/gumu/mishi1.c`）的 `do_ci`（`add_action("do_ci","ci")`）。

  刺砖探空：`ci brick`，须**手持兵器**。本函数不改出口，但会给玩家置
  `tmarks/砖 = 1` —— 这是同房 `do_zhan`（粘砖开门，见 `Zhan`）的前置门槛，
  因此一并移植（否则 `zhan brick` 永远是死内容）。

  LPC 原文：

      if (!arg || arg != "brick") return notify_fail("你要刺什么？\\n");
      if (!objectp(weapon = me->query_temp("weapon")))
          return notify_fail("要刺墙不用家伙恐怕不行吧！\\n");
      message_vision("$N拔出兵刃，向青砖轻轻刺去，只听得空空作声，青砖的另一头仿佛是空的。\\n", me);
      me->set_temp("tmarks/砖", 1);
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Trigger

  @self_room "gumu:mishi1"
  @mark_key "tmarks/砖"

  @what "你要刺什么？\n"
  @no_weapon "要刺墙不用家伙恐怕不行吧！\n"
  @probed "$N拔出兵刃，向青砖轻轻刺去，只听得空空作声，青砖的另一头仿佛是空的。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "brick" ->
        Trigger.render(conn, @what)

      Trigger.weapon_skill_type(Trigger.current(conn)) == nil ->
        Trigger.render(conn, @no_weapon)

      true ->
        conn
        |> Trigger.broadcast(@self_room, @probed)
        |> Trigger.put_temp(@mark_key, 1)
    end
  end
end

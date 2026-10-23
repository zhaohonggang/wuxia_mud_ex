defmodule Kantele.World.RoomActions.Jingzhou.Houyuan.Unlock do
  @moduledoc """
  荆州衙门后院（`d/jingzhou/houyuan.c`）的 `do_unlock`（`add_action("do_unlock","unlock")`）。

  钥匙开门：`unlock men` / `unlock east`，须随身带「鬼房钥匙」（`guifang key`，
  物品 alias 见 `data/world/jingzhou.ucl`）。门已开则提示；否则开
  `east`→`jingzhou:dongxiang`（**永久**，无定时关），钥匙折断被消耗。

  LPC 原文：

      if (query("exits/east")) return notify_fail("这扇门已经是打开的。\\n");
      if (!arg || (arg != "men" && arg != "east")) return notify_fail("你要打开什么？\\n");
      if (!(ob = present("guifang key", this_player()))) return notify_fail("你不会撬锁。\\n");
      set("exits/east", __DIR__"dongxiang");
      message_vision("$N用一把钥匙打开房门，可是钥匙却断了。\\n", this_player());
      destruct(ob);

  同房 `valid_leave`（管家拦路，UCL 已带 `valid_leave` 数据块）不在本 handler 内。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.Trigger

  @self_room "jingzhou:houyuan"
  @target_room "jingzhou:dongxiang"
  @dir "east"
  @key_name "guifang key"

  @already_open "这扇门已经是打开的。\n"
  @what "你要打开什么？\n"
  @no_key "你不会撬锁。\n"
  @opened "$N用一把钥匙打开房门，可是钥匙却断了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      DynamicExit.open?(@self_room, @dir) ->
        Trigger.render(conn, @already_open)

      arg not in ["men", "east"] ->
        Trigger.render(conn, @what)

      not Helpers.carries?(Trigger.current(conn), @key_name) ->
        Trigger.render(conn, @no_key)

      true ->
        unlock(conn)
    end
  end

  defp unlock(conn) do
    {_removed?, conn} = Helpers.take_item(conn, @key_name)
    Trigger.reveal(conn, @self_room, @dir, @target_room, @opened, nil, nil)
  end
end

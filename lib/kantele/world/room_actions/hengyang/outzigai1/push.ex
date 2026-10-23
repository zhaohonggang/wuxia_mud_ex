defmodule Kantele.World.RoomActions.Hengyang.Outzigai1.Push do
  @moduledoc """
  衡阳突石上（`d/hengyang/outzigai1.c`）的 `do_push`（`add_action("do_push",({"tui","push"}))`）。

  推石壁：`push bi` / `tui bi`（两动词同一函数），须**内力 ≥1500 且基本拳 ≥80**。
  开 `enter`→`hengyang:zigaihole` 并打通下层 `out`→本房（双向），**13 秒**后
  `auto_close` 把两侧出口与两侧房间 temp `marks/推` 一起回收。

  LPC 原文：

      if (!arg || arg != "bi") { write("你要推什么？\\n"); return 1; }
      if (obhere->query_temp("marks/推")) { write("石门已经被推开了。\\n"); return 1; }   // 房间级 temp
      if (me->query("neili") < 1500 || me->query_skill("unarmed",1) < 80) {
          write("你使出浑身解数用力推石壁，可以石壁却纹丝不动。\\n"); return 1;
      }
      message_vision("$N用力将石壁往旁边一推，轰！地一声，石壁已被推开，露出一个山洞来。这竟是一扇石门。\\n", me);
      tell_room(obhere, "阳光照射了进来，耀眼夺目。\\n");     // 本房纯文本
      tell_room(obj, "洞外轰！地一声，像是有人将石门推开了。\\n");   // 邻房纯文本
      set("exits/enter", __DIR__"zigaihole");
      obhere->set_temp("marks/推", 1); obj->set_temp("marks/推", 1);
      obj->set("exits/out", __DIR__"outzigai1");
      call_out("auto_close", 13);

  `auto_close`：两侧 `tell_room` 各一条 → 删本房 `enter`、邻房 `out`、两侧房间
  temp `marks/推`。

  关于 `set("long", ...)` 改房间描述：转换器已把推开门后的长描述直接写进 UCL
  `description`（`站在这里向下望才发现自己已经离地面有十来丈高了…`），运行时无需再改。

  房间级 `marks/推` 存在房间进程 `data.state`（与 `ItemDescHandlers.RoomTempTiers`
  读的 `marks/推` 同键——`look bi` 的「石门已经被推开了」文案因此即时生效）。
  temp 回收走独立 `:timer.apply_after`（回调只碰 room_id 级原语，与
  `DynamicExit.do_close_after` 同一范式）；开门期间 `marks/推` 已挡住二次推动，
  无需 `remove_call_out` 取消语义。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.MoveStone

  @self_room "hengyang:outzigai1"
  @target_room "hengyang:zigaihole"
  @dir "enter"
  @neighbor_dir "out"
  @mark_key "marks/推"
  @neili_gate 1500
  @unarmed_gate 80
  @close_seconds 13

  @what "你要推什么？\n"
  @already_open "石门已经被推开了。\n"
  @too_weak "你使出浑身解数用力推石壁，可以石壁却纹丝不动。\n"
  @opened "\n$N用力将石壁往旁边一推，轰！地一声，石壁已被推开，露出一个山洞来。这竟是一扇石门。\n\n"
  @self_light "阳光照射了进来，耀眼夺目。\n\n"
  @neighbor_light "洞外轰！地一声，像是有人将石门推开了。\n"
  @close_self "\n轰！轰！轰！不知道谁将石门关上了，顿时山洞里变得阴暗起来。\n"
  @close_neighbor "\n轰！轰！轰！不知道谁将石门关上了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "bi" ->
        MoveStone.render(conn, @what)

      MoveStone.room_temp(@self_room, @mark_key) not in [nil, 0] ->
        MoveStone.render(conn, @already_open)

      true ->
        push(conn)
    end
  end

  defp push(conn) do
    char = MoveStone.current(conn)

    if MoveStone.neili(char) < @neili_gate or MoveStone.skill(char, "unarmed") < @unarmed_gate do
      MoveStone.render(conn, @too_weak)
    else
      conn = MoveStone.broadcast(conn, @self_room, @opened)
      Room.tell_room(%Room{id: @self_room}, @self_light)
      Room.tell_room(%Room{id: @target_room}, @neighbor_light)

      conn = DynamicExit.open(conn, @self_room, @dir, @target_room, "")
      Room.set_exit(@target_room, @neighbor_dir, @self_room)
      MoveStone.put_room_temp(@self_room, @mark_key, 1)
      MoveStone.put_room_temp(@target_room, @mark_key, 1)

      DynamicExit.close_after(
        @close_seconds * 1000,
        @self_room,
        "exit_timer:movestone:" <> @self_room,
        [{@self_room, @dir, @close_self}, {@target_room, @neighbor_dir, @close_neighbor}],
        only_if_open: false
      )

      :timer.apply_after(
        @close_seconds * 1000,
        MoveStone,
        :clear_room_temps,
        [[{@self_room, @mark_key}, {@target_room, @mark_key}]]
      )

      conn
    end
  end
end

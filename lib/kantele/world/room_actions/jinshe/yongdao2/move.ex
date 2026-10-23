defmodule Kantele.World.RoomActions.Jinshe.Yongdao2.Move do
  @moduledoc """
  金蛇洞甬道（`d/jinshe/yongdao2.c`）的 `do_move`（`add_action("do_move","move")`）。

  推巨石开山洞：`move stone`，须**内力 ≥1500 且臂力 ≥35**（不足则播「吃奶的劲
  也没能移动」并把内力清零）。开 `north`→`jinshe:shandong`，5 秒后巨石回位
  自动关，成功扣 1000 内力。

  LPC 原文：

      if (!arg || arg != "stone") return notify_fail("你要移动什么？\\n");
      if (me->query("neili") < 1500 || me->query_str() < 35) {
          message_vision("$N使出吃奶的劲也没能移动巨石。\\n", me);
          me->set("neili", 0); return 1;
      }
      message_vision("$N站在石前，双掌发力推动巨石，只听得巨石吱吱连声，缓缓\\n向后移去，现出一个山洞来。\\n", me);
      set("exits/north", __DIR__"shandong");
      remove_call_out("close"); call_out("close", 5, this_object());
      me->add("neili", -1000);
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.MoveStone

  @self_room "jinshe:yongdao2"
  @target_room "jinshe:shandong"
  @dir "north"
  @neili_gate 1500
  @str_gate 35
  @neili_cost 1000
  @close_seconds 5

  @what "你要移动什么？\n"
  @too_weak "$N使出吃奶的劲也没能移动巨石。\n"
  @opened "$N站在石前，双掌发力推动巨石，只听得巨石吱吱连声，缓缓\n向后移去，现出一个山洞来。\n"
  @close_msg "\n只见巨石又吱吱地回到原地。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    if String.trim(arg) != "stone" do
      MoveStone.render(conn, @what)
    else
      push(conn)
    end
  end

  defp push(conn) do
    char = MoveStone.current(conn)

    if MoveStone.neili(char) < @neili_gate or MoveStone.str(char) < @str_gate do
      conn
      |> MoveStone.broadcast(@self_room, @too_weak)
      |> MoveStone.set_neili(0)
    else
      conn
      |> MoveStone.deduct_neili(@neili_cost)
      |> MoveStone.reveal(@self_room, @dir, @target_room, @opened,
        seconds: @close_seconds,
        close_msg: @close_msg
      )
    end
  end
end

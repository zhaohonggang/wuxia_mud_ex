defmodule Kantele.World.RoomActions.Tiezhang.Wmfeng.Move do
  @moduledoc """
  铁掌帮坟场（`d/tiezhang/wmfeng.c`）的 `do_move`（`add_action("do_move","move")`）。

  推墓碑：`move bei`，须**臂力 ≥30 且基本内功 ≥100**。开 `enter`→`tiezhang:shijie_1`，
  10 秒后墓碑合回自动关（`close_passage` 有守卫 → `only_if_open: true`）。
  与荆州乱葬岗同一套门控与文案，仅目标房不同。

  LPC 原文：

      if (! arg || arg != "bei") return notify_fail("你要推什么？\\n");
      if ((int)me->query_str() < 30) return notify_fail("你将吃奶的劲都用上了，可还是无法把石碑推开。\\n");
      if ((int)me->query_skill("force", 1) < 100) return notify_fail("你推了半天，发现石碑还是纹丝不动。\\n");
      write("你扎下马步，深深的吸了口气，将墓碑缓缓的向旁推开，下面露出一个黑洞洞的入口。\\n");
      message("vision", me->name() + "双膀用力，将墓碑向旁缓缓推开，下面露出一个黑洞洞的入口。\\n",
              environment(me), ({me}));
      set("exits/enter", __DIR__"shijie-1");
      remove_call_out("close_passage"); call_out("close_passage", 10);

  注：LPC 目标文件名 `shijie-1.c`，转换器规范化为房号 `tiezhang:shijie_1`
  （连字符→下划线，同 `quanzhen:fu_woshi`）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.MoveStone

  @self_room "tiezhang:wmfeng"
  @target_room "tiezhang:shijie_1"
  @dir "enter"
  @str_gate 30
  @force_gate 100
  @close_seconds 10

  @what "你要推什么？\n"
  @weak_str "你将吃奶的劲都用上了，可还是无法把石碑推开。\n"
  @weak_force "你推了半天，发现石碑还是纹丝不动。\n"
  @self_msg "你扎下马步，深深的吸了口气，将墓碑缓缓的向旁推开，下面露出一个黑洞洞的入口。\n"
  @close_msg "墓碑发出隆隆的声音，缓缓移回原处。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    char = MoveStone.current(conn)

    cond do
      String.trim(arg) != "bei" ->
        MoveStone.render(conn, @what)

      MoveStone.str(char) < @str_gate ->
        MoveStone.render(conn, @weak_str)

      MoveStone.skill(char, "force") < @force_gate ->
        MoveStone.render(conn, @weak_force)

      true ->
        push(conn, char)
    end
  end

  defp push(conn, char) do
    conn = MoveStone.render(conn, @self_msg)

    conn =
      MoveStone.broadcast_except(
        conn,
        @self_room,
        "#{char.name}双膀用力，将墓碑向旁缓缓推开，下面露出一个黑洞洞的入口。\n"
      )

    MoveStone.reveal(conn, @self_room, @dir, @target_room, "",
      seconds: @close_seconds,
      close_msg: @close_msg,
      only_if_open: true
    )
  end
end

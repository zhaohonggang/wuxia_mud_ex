defmodule Kantele.World.RoomActions.Meizhuang.Gate.Knock do
  @moduledoc """
  梅庄大门（`d/meizhuang/gate.c`）的 `do_knock`（`add_action("do_knock","knock")`）。

  铜环暗号：依次敲击 4 → 2 → 5 → 3（顺序错即清零重来），集齐后开启
  `north`↔`meizhuang:tianjing` 双向门，10 秒后护院关上。这与 `meizhuang:tianjing`
  的 `open`（P5-4ak）打通的是**同一组**双向出口，殊途同归。

  LPC 原文（四段独立判定 + 兜底）：

      if (query("exits/north")) return notify_fail("门已经是开着的...\\n");
      if (arg=="4") { msg; me->set_temp("step",1); return 1; }
      if (arg=="2") { msg; step = (step==1)?2:0; return 1; }
      if (arg=="5") { msg; step = (step==2)?3:0; return 1; }
      if (arg=="3") { msg; if (step==3){ step=0; 开双向门; call_out("close_passage",10);} else step=0; return 1; }
      message_vision("...敲了几下...\\n"); return 1;

  暗号进度 `step` 是**玩家级**（`me->set_temp`），各敲各的；这里搬到
  `meta.temp["knock_step"]`。非 4/2/5/3 的敲击不改 `step`（只播「敲了几下」）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.KnockPull

  @self_room "meizhuang:gate"
  @target_room "meizhuang:tianjing"
  @dir "north"
  @neighbor_dir "south"
  @step_key "knock_step"
  @timer_key "exit_timer:gate_close_passage"
  @delay_ms 10_000

  @already_open "门已经是开着的，不用再费力去敲了！\n"
  @knock4 "$N走上前去将门上铜环敲了四下。\n"
  @knock2 "$N走上前去将门上铜环敲了两下。\n"
  @knock5 "$N走上前去将门上铜环敲了五下。\n"
  @knock3 "$N走上前去将门上铜环敲了三下。\n"
  @knocked "$N走上前去将门上铜环敲了几下。\n"
  @open_self "你静静的等候，过了半晌，大门终于缓缓的打开了。\n"
  @open_neighbor "梅庄大门上的铜环有节奏地响了四声，大门给打开了。\n"
  @close_self "只听“嘎嘎嘎”几声，梅庄内的护院将大门轻轻关上了。\n"
  @close_neighbor "大门被护院轻轻关上了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      DynamicExit.open?(@self_room, @dir) ->
        Helpers.render_to_player(conn, @already_open)

      arg == "4" ->
        KnockPull.put_temp(Helpers.broadcast_vision(conn, @self_room, @knock4), @step_key, 1)

      arg == "2" ->
        step_then(conn, 1, 2, @knock2)

      arg == "5" ->
        step_then(conn, 2, 3, @knock5)

      arg == "3" ->
        step3(conn)

      true ->
        Helpers.broadcast_vision(conn, @self_room, @knocked)
    end
  end

  defp step_then(conn, expect, next, vision) do
    conn = Helpers.broadcast_vision(conn, @self_room, vision)
    step = KnockPull.get_temp(conn, @step_key, 0)
    KnockPull.put_temp(conn, @step_key, if(step == expect, do: next, else: 0))
  end

  defp step3(conn) do
    conn = Helpers.broadcast_vision(conn, @self_room, @knock3)

    if KnockPull.get_temp(conn, @step_key, 0) == 3 do
      conn
      |> KnockPull.put_temp(@step_key, 0)
      |> open_gate()
    else
      KnockPull.put_temp(conn, @step_key, 0)
    end
  end

  defp open_gate(conn) do
    conn
    |> DynamicExit.open(@self_room, @dir, @target_room, @open_self)
    |> set_neighbor()
    |> schedule_close()
  end

  defp set_neighbor(conn) do
    Room.set_exit(@target_room, @neighbor_dir, @self_room)
    Room.tell_room(%Room{id: @target_room}, @open_neighbor)
    conn
  end

  defp schedule_close(conn) do
    DynamicExit.close_after(
      @delay_ms,
      @self_room,
      @timer_key,
      [{@self_room, @dir, @close_self}, {@target_room, @neighbor_dir, @close_neighbor}],
      only_if_open: true
    )

    conn
  end
end

defmodule Kantele.World.RoomActions.Shaolin.Guangchang1.Knock do
  @moduledoc """
  少林广场（`d/shaolin/guangchang1.c`）的 `do_knock`（`add_action("do_knock","knock")`）。

  敲 `gate`/`north` 开 `north`→`shaolin:smdian` 双向门（同时打通 `smdian` 的
  `south`→本房），10 秒后护院把大门关上。

  LPC 原文：

      if (query("exits/north")) return notify_fail("大门已经是开着了。\\n");
      if (! arg || (arg != "gate" && arg != "north")) return notify_fail("你要敲什么？\\n");
      set("exits/north", __DIR__"smdian");
      message_vision("...敲了敲门...壮年僧人应声打开大门。\\n", me);
      room->set("exits/south", __FILE__);
      message("vision", "...外面传来一阵敲门声...", room);
      call_out("close_gate", 10);

  `valid_leave`（俗家弟子/性别/负神入寺检查）已由转换器抽进 UCL `valid_leave`
  块，**不在本 handler 内**——本 handler 只管开门。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.KnockPull

  @self_room "shaolin:guangchang1"
  @target_room "shaolin:smdian"
  @dir "north"
  @neighbor_dir "south"
  @delay_s 10

  @already_open "大门已经是开着了。\n"
  @what "你要敲什么？\n"
  @open_self "$N轻轻地敲了敲门，只听吱地一声，衣位壮年僧人应声打开大门。\n"
  @open_neighbor "外面传来一阵敲门声，壮年僧人应声上前把大门开。\n"
  @close_self "只听乒地一声，里面有人把大门关上了。\n"
  @close_neighbor "壮年僧人上前把大门关了起来。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    cond do
      KnockPull.open?(@self_room, @dir) ->
        Helpers.render_to_player(conn, @already_open)

      arg not in ["gate", "north"] ->
        Helpers.render_to_player(conn, @what)

      true ->
        KnockPull.reveal_both(
          conn,
          @self_room,
          @dir,
          @target_room,
          @target_room,
          @neighbor_dir,
          @open_self,
          @open_neighbor,
          {@delay_s, @close_self, @close_neighbor}
        )
    end
  end
end

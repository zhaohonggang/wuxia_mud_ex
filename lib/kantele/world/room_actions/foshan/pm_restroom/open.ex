defmodule Kantele.World.RoomActions.Foshan.PmRestroom.Open do
  @moduledoc """
  `d/foshan/pm_restroom.c` 的 `do_open`（英雄会馆拍卖会大门的**管理员**开关）。

  LPC 原文：

      void init()
      {
              add_action("do_look", "look");

              if (wiz_level(this_player()) >= 3)
              {
                      add_action("do_open", "open");
                      add_action("do_close", "close");
              }
      }

      int do_open()
      {
              object me = this_player();

              if (query("exits/south"))
                      return notify_fail("门已经是开着的了。\\n");

              set("exits/south", __DIR__"pmc");

              message_vision(HIY "$N" HIY "轻轻一推，将通向英雄会馆的"
                             "小门开启了。\\n" NOR, me);

              shout(HIY "【商界传闻】" NOR + WHT + me->name() + WHT "[" +
                    me->query("id") + WHT "]开启了佛山英雄会馆的店铺拍"
                    "卖会的大门。\\n" NOR);

              write("你开通了店铺拍卖会的路径。\\n");
              return 1;
      }

  ## 移植要点

  - **管理员门控**：LPC 只对 `wiz_level >= 3` 的玩家 `add_action`，普通玩家输入
    `open` 会落到全局 `open` 命令。本移植把动作注册在 UCL（房间级），所以门控
    搬进 handler：非管理员返回 `:not_handled`（等价 LPC「没注册这个 action」），
    由 `RoomActionDispatcher` 放行给全局 `OpenCommand`。
  - `shout(...)` → `Kantele.Communication.announce("general", text)`：全服
    `general` 频道播报（`shout()` 在本移植没有独立命令，`general` 是它的对应
    频道，见 `world/kickoff.ex` / `world/story.ex` 的同类用法）。
  - 播报里的 `me->name()` / `me->query("id")` 是**拼进文本的玩家名与 id**，不是
    `$N` 占位符 —— `announce/2` 是纯文本频道消息，没有 `VisionView` 渲染，所以
    这里必须直接插值。
  - `write("你开通了店铺拍卖会的路径。\\n")` 在 `message_vision` 之后 →
    `render_to_player/2`（只给行动者）。
  """
  use Kantele.World.RoomAction

  alias Kantele.Admin.Access
  alias Kantele.Communication
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @target_room "foshan:pmc"
  @required_wiz_level 3

  @opened "$N轻轻一推，将通向英雄会馆的小门开启了。\n"
  @self_notice "你开通了店铺拍卖会的路径。\n"
  @rumor_prefix "【商界传闻】"
  @rumor_suffix "开启了佛山英雄会馆的店铺拍卖会的大门。\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    case Map.get(conn, :character) do
      %{name: name, id: id} = character when is_binary(room_id) ->
        if Access.has_level?(character, @required_wiz_level) do
          open_door(conn, room_id, name, id)
        else
          # LPC 没给普通玩家注册这个 action → 交回全局 `open`
          :not_handled
        end

      _ ->
        :not_handled
    end
  end

  defp open_door(conn, room_id, name, id) do
    if DynamicExit.open?(room_id, "south") do
      Helpers.render_to_player(conn, "门已经是开着的了。\n")
    else
      conn
      |> DynamicExit.open(room_id, "south", @target_room, @opened)
      |> announce_opening(name, id)
      |> Helpers.render_to_player(@self_notice)
    end
  end

  defp announce_opening(conn, name, id) do
    Communication.announce("general", @rumor_prefix <> "#{name}[#{id}]" <> @rumor_suffix)
    conn
  end
end

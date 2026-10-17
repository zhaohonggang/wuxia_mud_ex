defmodule Kantele.World.RoomActions.Baituo.Neishi.Move do
  @moduledoc """
  P5-1b-3 样板 #3：移植自 `d/baituo/neishi.c` 的 `do_move`（状态变更：开/关密道）。

  LPC 源（已回源核对）：

      int do_move(string arg)
      {
          object me = this_player();
          if (arg != "pen")
                  return notify_fail("你要搬什么？\\n");
          if (me->query("born_family") != "欧阳世家")
                  return notify_fail("你移动了一下花盆，却没发现什么特别的东西。\\n");
          if (! query("exits/down"))
          {
                  set("exits/down", __DIR__"midao");
                  message_vision(HIY "\\n$N" HIY "移动花盆，只见花盆下面"
                                     "露出一个黑幽幽的洞口。\\n\\n" NOR, me);
              } else
              {
                  delete("exits/down");
                  message_vision(HIY "\\n$N" HIY "把花盆搬回原位，洞口顿"
                                     "时被封住了。\\n\\n" NOR, me);
              }
              return 1;
      }

  ## 移植要点（首个状态变更 handler）
  - `arg != "pen"` → 只给本人提示；`born_family != "欧阳世家"` → 只给本人提示。
  - `query("exits/down")` → `Room.has_exit_by_id?/2`（读房间进程 exits 列表）。
  - `set("exits/down", __DIR__"midao")` → `Room.set_exit/3`（运行期向房间进程
    `state.data.exits` 追加 `%Kalevala.World.Exit{}`，look/移动立即生效）。
  - `delete("exits/down")` → `Room.delete_exit/2`。
  - `message_vision(...)` → `Helpers.broadcast_vision/3`（房间广播）。
  - 动词 `"move"` **不在全局命令表**（`lib/kantele/character/commands.ex` 无
    `parse("move", ...)`），故仅在本房间拦截，不覆盖全局命令（P7 安全）。
  - LPC 颜色宏 `HIY`/`NOR` 已剥离，仅保留文案。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @target_room "baituo:midao"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    cond do
      String.trim(arg) != "pen" ->
        Helpers.render_to_player(conn, "你要搬什么？\n")

      born_family(conn) != "欧阳世家" ->
        Helpers.render_to_player(conn, "你移动了一下花盆，却没发现什么特别的东西。\n")

      Room.has_exit_by_id?(room_id, "down") ->
        Room.delete_exit(room_id, "down")

        Helpers.broadcast_vision(
          conn,
          room_id,
          "\n$N把花盆搬回原位，洞口顿时被封住了。\n\n"
        )

      true ->
        Room.set_exit(room_id, "down", @target_room)

        Helpers.broadcast_vision(
          conn,
          room_id,
          "\n$N移动花盆，只见花盆下面露出一个黑幽幽的洞口。\n\n"
        )
    end
  end

  # 对应 LPC `me->query("born_family")`：角色 meta.family.born_family。
  defp born_family(conn) do
    case Map.get(conn, :character) do
      %{meta: meta} ->
        family = Map.get(meta, :family) || %{}
        Map.get(family, :born_family)

      _ ->
        nil
    end
  end
end

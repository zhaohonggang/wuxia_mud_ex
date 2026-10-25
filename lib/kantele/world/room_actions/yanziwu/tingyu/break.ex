defmodule Kantele.World.RoomActions.Yanziwu.Tingyu.Break do
  @moduledoc """
  `d/yanziwu/tingyu.c` 的 `do_break`（`add_action("do_break", "break")`，目标词 `qin`）
  —— 听雨居瑶琴暗器（P5-6 门/容器收尾批：最后 2 处 `do_break` 之一）。

  LPC 原文：

      int do_break(string arg)
      {
              if (! arg || arg != "qin")
              return notify_fail("你要击开什么？\\n");

              message_vision("\\n$N一掌击开瑶琴，只听“唰”的一声，突然银光一闪，\\n"+
                      "一枚梅花镖倏的射出,“噗”的一声射入了$N的人中穴。\\n",
              this_player());

              if ((int)this_player()->query("qi") < 200)
              this_player()->die();
              else
              this_player()->unconcious();
              return 1;
      }

  ## 移植要点

  - 目标词只认 `qin`（瑶琴），否则 `notify_fail("你要击开什么？\\n")`。
  - `$N` 在文案里出现两次、都指行动者：`Helpers.broadcast_vision/3` 内部把
    `$N` 统一换成 `{npc}`（行动者见「你」、旁观者见姓名），与 LPC
    `message_vision` 语义一致。
  - `query("qi") < 200` 读**当前** qi（`meta.vitals.qi`，不是 max）：
    - `< 200` → `Damage.die/2`（死亡结算）
    - `>= 200` → `Damage.unconcious/1`（晕倒）
    两者都走 `RoomActions.Break` 共享原语的同名封装（与陷阱 `trap_event` 同款
    API），不需要 `conn` 之外的上下文。
  - 无门控、无出口变化、无定时器——本房 `break` 是纯杀伤陷阱。
  - `break` 非全局命令，遮蔽不损失既有功能。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  @vision "\n$N一掌击开瑶琴，只听“唰”的一声，突然银光一闪，\n一枚梅花镖倏的射出,“噗”的一声射入了$N的人中穴。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) == "qin" do
      conn
      |> Break.broadcast(room_id, @vision)
      |> resolve_dart()
    else
      Helpers.render_to_player(conn, "你要击开什么？\n")
    end
  end

  # LPC `query("qi") < 200` → die()，否则 unconcious()
  defp resolve_dart(conn) do
    if Break.current(conn).meta.vitals.qi < 200 do
      Break.die(conn)
    else
      Break.unconcious(conn)
    end
  end
end

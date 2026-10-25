defmodule Kantele.World.RoomActions.Wudu.Mishi.Open do
  @moduledoc """
  五毒密石室（`wudu:mishi`）开石匣取千蛛万毒手秘笈（P5-6 门/容器第二批）。

  LPC 源：`d/wudu/mishi.c` 的 `do_open`（`add_action("do_open", "open")`）：

      int do_open(string arg)
      {
              object me, ob;
              me = this_player();

              if( !arg || arg != "xia")
                      return 0;                       // ← 放行全局 open

              if( query("mishi_book") == 1 && me->query("can_learn/qianzhu-wandushou") )
              {
                      message_vision(HIC "$P打开石匣，发现内有一束绢册，连忙取了出来。\\n"
                                     NOR, me);
                      add("mishi_book", -1);
                      ob = new(__DIR__"obj/qianzhumiji");
                      ob->move(me);
              } else
                      return notify_fail("\\n你打开石匣，但见里面空空如也。\\n");

              return 1;
      }

  ## 移植要点

  - `arg != "xia"` → **`:not_handled`**（LPC `return 0`）：本房只接管
    `open xia`，其它输入交还全局 `open` 命令。
  - `query("mishi_book")` 是**房间级状态**（LPC `create` 里 `set("mishi_book", 1)`）：
    用 `Room.get_state_by_id/3` 读、`put_state_by_id/3` 写；键缺失时按 `1` 计
    （等价 create 的初值），`add("mishi_book", -1)` 后写 `0`，之后恒走 else。
  - `me->query("can_learn/qianzhu-wandushou")` → `Helpers.flag?/2`
    （`attributes` → `meta.env` 两级读取）。
  - `new(...)->move(me)` → `Helpers.give_item/2`（`wudu:qianzhumiji`）。
  - LPC `$P` 在句首作主语，而 `VisionView` 只归一化 `{npc}`/`{name}`：这里按
    `{npc}` 处理（行动者见「你」、旁观者见姓名），与同句位的 `$N` 语义一致。

  ## 已知语料缺陷（发秘笈分支当前不可达）

  全语料 grep：`can_learn/qianzhu-wandushou` **只有两处读取、零处 `set`**
  （`wudu/mishi.c` L45 本函数、L68 `do_think`）。因此该 flag 恒为假，
  `mishi_book == 1 && can_learn` 永不成立 —— 玩家永远看到「空空如也」。
  这与 `lingxiao:cheng`（LPC 目标文件缺失）同族：**结构按 LPC 忠实实现，
  行为如实记录**；将来若有 `set("can_learn/...")` 的语料补入，本分支自动生效。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @state_key "mishi_book"
  @flag "can_learn/qianzhu-wandushou"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case String.trim(arg) do
      "xia" -> open_xia(conn, room_id)
      _other -> :not_handled
    end
  end

  defp open_xia(conn, room_id) do
    character = conn.private.update_character || conn.character

    if book_left?(room_id) and Helpers.flag?(character, @flag) do
      conn
      |> then(fn c -> Room.put_state_by_id(room_id, @state_key, 0); c end)
      |> Helpers.broadcast_vision(room_id, "{npc}打开石匣，发现内有一束绢册，连忙取了出来。\n")
      |> Helpers.give_item("wudu:qianzhumiji")
    else
      Helpers.render_to_player(conn, "\n你打开石匣，但见里面空空如也。\n")
    end
  end

  # LPC `create` 里 `set("mishi_book", 1)`：键缺失即未被扣过，按 1 计。
  defp book_left?(room_id) do
    case Room.get_state_by_id(room_id, @state_key) do
      nil -> true
      value -> value == 1
    end
  end
end

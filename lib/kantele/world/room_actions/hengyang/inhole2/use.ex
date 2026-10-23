defmodule Kantele.World.RoomActions.Hengyang.Inhole2.Use do
  @moduledoc """
  衡阳水帘洞内（`d/hengyang/inhole2.c`）的 `do_use`（`add_action("do_use","use")`）。

  点火折照洞：`use fire`，须随身带火折（`fire`，alias 见 `data/world/xiyu.ucl`）。
  点燃后同时开两个出口 `west`→`hengyang:zigai1` 与 `north`→`hengyang:zigai2`
  （**永久**，LPC 靠 `reset()` 回收，本引擎房间进程重启即还原），并给玩家记
  `marks/走1`。

  LPC 原文：

      if (! arg || arg != "fire") return 0;
      if (! present("fire", me)) return 0;
      write("\\n你点燃了火折，发现这里有出口。\\n\\n");
      me->set_temp("marks/走1", 1);
      delete("long"); set("long", @LONG ... LONG);   // 改房间描述
      set("exits/west", __DIR__"zigai1");
      set("exits/north", __DIR__"zigai2");

  两个 `return 0`（静默放行全局 `use`）→ 这里返回 `:not_handled`。

  关于 `set("long", ...)`：转换器已把点火后的长描述直接写进 UCL
  （`data/world/hengyang.ucl` 里 `inhole2` 的 `description` 就是「借着火光…」那句），
  本引擎房间长描述无运行时改写入口，故运行时只补两个出口，记为数据层近似。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.RoomActions.Trigger

  @self_room "hengyang:inhole2"
  @fire_name "fire"
  @mark_key "marks/走1"
  @exits [{"west", "hengyang:zigai1"}, {"north", "hengyang:zigai2"}]

  @lit "\n你点燃了火折，发现这里有出口。\n\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    cond do
      String.trim(arg) != "fire" -> :not_handled
      not Helpers.carries?(Trigger.current(conn), @fire_name) -> :not_handled
      true -> light(conn)
    end
  end

  defp light(conn) do
    conn = Trigger.render(conn, @lit)
    conn = Trigger.put_temp(conn, @mark_key, 1)
    Trigger.reveal_many(conn, @self_room, @exits)
  end
end

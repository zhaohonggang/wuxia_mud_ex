defmodule Kantele.World.RoomActions.Xiakedao.Gudi.Mai do
  @moduledoc """
  侠客岛墓地（`d/xiakedao/gudi.c`）的 `do_mai`（`add_action("do_mai","mai")` +
  `add_action("do_mai","bury")`，两个动词同一函数）。

  埋骨掘墓：`mai gu` / `bury gu`。内力 > 100 才挖得动（扣 100），开
  `east`→`xiakedao:midao6`，5 秒后石门自动合上；内力不足则挖不动并清零。

  LPC 原文：

      if (! arg || arg != "gu") { write("什么？\\n"); return 1; }
      message_vision("$N找了一块松软的地面，用力挖了起来。\\n", me);
      n = me->query("neili");
      if (n > 100) {
          message_vision("大约过了半个时辰，$N恭恭敬敬的把老者的遗骨放了进去，"
                         "埋了起来。突然东面\\n出现了一个石门。\\n", me);
          set("exits/east", __DIR__"midao6");
          me->add("neili", -100);
          remove_call_out("close"); call_out("close", 5, me);
      } else {
          message_vision("$N的气力不足，挖了几下就干不动了。\\n", me);
          me->set("neili", 0);
      }

  `close(object room)` 回调无 `if (!query(...))` 守卫，故 `only_if_open: false`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Trigger

  @self_room "xiakedao:gudi"
  @target_room "xiakedao:midao6"
  @dir "east"
  @neili_gate 100
  @neili_cost 100
  @close_seconds 5

  @what "什么？\n"
  @digging "$N找了一块松软的地面，用力挖了起来。\n"
  @buried "大约过了半个时辰，$N恭恭敬敬的把老者的遗骨放了进去，埋了起来。突然东面\n出现了一个石门。\n"
  @too_weak "$N的气力不足，挖了几下就干不动了。\n"
  @close_msg "石门自动的合上了。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    if String.trim(arg) != "gu" do
      Trigger.render(conn, @what)
    else
      dig(conn)
    end
  end

  defp dig(conn) do
    conn = Trigger.broadcast(conn, @self_room, @digging)
    char = Trigger.current(conn)

    if Trigger.neili(char) > @neili_gate do
      conn
      |> Trigger.deduct_neili(@neili_cost)
      |> Trigger.reveal(@self_room, @dir, @target_room, @buried, @close_msg, @close_seconds)
    else
      conn
      |> Trigger.broadcast(@self_room, @too_weak)
      |> Trigger.set_neili(0)
    end
  end
end

defmodule Kantele.World.RoomActions.Hengyang.Furong1.Climb do
  @moduledoc """
  `d/hengyang/furong1.c` 的 `do_climb`（`add_action("do_climb", "climb")`）。

  LPC 原文：

      int do_climb(string arg)
      {
              object me = this_player();

              if (! arg || arg != "stone")
                    return notify_fail("你想爬什么？\\n");

              write(HIG "\\n你踩着洞中突出的石头上，很快爬出了洞口。\\n\\n" NOR);

              me->move(__DIR__"furongfeng");

              return 1;
      }

  洞口在芙蓉峰上，爬出去直达 `hengyang:furongfeng`。参数必须是 `stone`
  （房间描述里的「突出的石头」），否则只提示不动作。颜色宏按仓库既有约定
  剥离，只保留文本。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @target_room_id "hengyang:furongfeng"

  @prompt "你想爬什么？\n"
  @climbing "\n你踩着洞中突出的石头上，很快爬出了洞口。\n\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    case String.trim(arg) do
      "stone" ->
        conn
        |> Helpers.render_to_player(@climbing)
        |> Helpers.move_to(@target_room_id)

      _ ->
        Helpers.render_to_player(conn, @prompt)
    end
  end
end

defmodule Kantele.World.RoomActions.Tiezhang.Mishi.Open do
  @moduledoc """
  铁掌山密室（`tiezhang:mishi`）开石盒取掌谱（P5-6 门/容器第二批）。

  LPC 源：`d/tiezhang/mishi.c` 的 `do_open`（`add_action("do_open", "open")`）：

      int do_open(string arg)
      {
              object me = this_player();
              object ob;

              if (!arg || (arg != "he" && arg != "shi he"))
              {
                      return notify_fail("你想打开什么？\\n");
              }
              else
              {
                      if (!present("tiezhang zhangpu", me))
                      {
                              write("你用力打开石盒，发现里面有一本落满尘土的书籍。"
                                    "你急忙把它捡起揣在怀中。\\n");
                              ob = new("/d/tiezhang/obj/zhangpu");
                              ob->move(me);
                              return 1;
                      }
                      write("你用力打开石盒，发现里面空空的什么也没有。\\n");
                      return 1;
              }
      }

  ## 移植要点

  - `present("tiezhang zhangpu", me)` → `Helpers.carries?/2`（`tiezhang:zhangpu`
    的 aliases 含 "tiezhang zhangpu"，按 id/别名匹配）。
  - `new(...)->move(me)` → `Helpers.give_item/2`（实例化并入背包 + 落盘）。
  - LPC 的 `notify_fail` 在 `add_action` 语境里等价于「本动词不处理，回显失败
    文案」；这里直接 `render_to_player`（与 `guanwai:xiuxishi` 等已注册房一致）。
  - 本 verb 与 `open` 全局命令同名：本房 UCL 无 `doors` 配置，遮蔽不损失既有
    功能（同 P5-4ae 约定）。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @args ["he", "shi he"]

  @impl true
  def run(conn, %{trailing: arg}) do
    arg = String.trim(arg)

    case arg do
      arg when arg in @args -> open_box(conn)
      _other -> Helpers.render_to_player(conn, "你想打开什么？\n")
    end
  end

  defp open_box(conn) do
    # `Helpers.current/1` 是私有函数，这里按同一约定自己取（`put_character/2`
    # 只写 `private.update_character`，须优先读它）。
    character = conn.private.update_character || conn.character

    if Helpers.carries?(character, "tiezhang zhangpu") do
      Helpers.render_to_player(conn, "你用力打开石盒，发现里面空空的什么也没有。\n")
    else
      conn
      |> Helpers.give_item("tiezhang:zhangpu")
      |> Helpers.render_to_player(
        "你用力打开石盒，发现里面有一本落满尘土的书籍。你急忙把它捡起揣在怀中。\n"
      )
    end
  end
end

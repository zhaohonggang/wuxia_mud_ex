defmodule Kantele.World.RoomActions.Shaolin.Putiyuan.Get do
  @moduledoc """
  `d/shaolin/putiyuan.c` 的 `do_get`（`add_action("do_get", "get")`）。

  LPC 原文：

      int do_get(string arg)
      {
          object me;
          object ob;

          me = this_player();

          if (! arg)
              return 0;

          if (arg != "book from hole" &&
              arg != "book in hole" &&
              arg != "jing from hole" &&
              arg != "jing in hole")
              return 0;

          if (query("status") != 4)
              return 0;

          // 已经存在秘本，或者书已经被拿走
          if (objectp(ob = find_object(MIJI)) &&
              environment(ob) || query("book_count") < 1)
          {
              write("你想书想晕了头吗？那里并没有什么书呀！\\n");
              return 1;
          }

          set("book_count", 0);
          ob = load_object(MIJI);
          if (! objectp(ob))
          {
              write("系统出现故障 - 找不到应该在这里的秘籍了 :)\\n");
              return 1;
          }

          message_vision("$N从小洞中将那本经书取出，放进包内。\\n", me);
          ob->move(me, 1);
          CHANNEL_D->do_channel(this_object(), "rumor", me->name(1) + "从少林寺窃走一本易筋经。");
          return 1;
      }

  ## 移植要点

  - 三处 `return 0` 全部映射成 `:not_handled`，把命令交回全局 `get`
    （`GetCommand`）—— 所以本房间的其他 `get xxx` 行为完全不变。
  - `status != 4` 同样 `return 0`：洞没开时 `get book from hole` 走全局 `get`，
    报「这里没有 book」之类的常规提示，与 LPC 一致。
  - `book_count < 1` 承接「书已被拿走」。LPC 还有 `find_object(MIJI) &&
    environment(ob)` 一条（秘本对象已被 load 且已落在某处），本引擎没有
    「唯一对象」注册表，故只保留 `book_count`；两者在正常流程里等价
    （拿书时就会把 `book_count` 置 0）。
  - **与 LPC 的差异（一处）**：LPC 先 `set("book_count", 0)` 再
    `load_object(MIJI)`，物品定义缺失时书就永久消失、谜题不可再解。本实现先
    `Items.get/1` 校验定义存在，缺失时只报「系统出现故障」而**不改** `book_count`，
    世界数据补齐后谜题自动恢复。世界数据正常时两者行为完全相同。
  - `CHANNEL_D->do_channel(..., "rumor", ...)` → `Kantele.Communication.announce/2`
    （`rumor` 频道在 `communication.ex` 的 `initial_channels/0` 注册；
    `announce/2` 内部吞异常，无频道/进程时不崩）。
  """

  use Kantele.World.RoomAction

  alias Kantele.Communication
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @status_key "status"
  @open_status 4
  @book_count_key "book_count"

  @book_item_id "clone_lib:yijinjing"
  @book_name "易筋经"

  @targets ["book from hole", "book in hole", "jing from hole", "jing in hole"]

  @no_book "你想书想晕了头吗？那里并没有什么书呀！\n"
  @missing_item "系统出现故障 - 找不到应该在这里的秘籍了 :)\n"
  @took_book "$N从小洞中将那本经书取出，放进包内。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    cond do
      # LPC `if (! arg) return 0;` + 目标串不匹配 → return 0
      String.trim(arg) not in @targets ->
        :not_handled

      # LPC `if (query("status") != 4) return 0;`
      status(room_id) != @open_status ->
        :not_handled

      book_count(room_id) < 1 ->
        Helpers.render_to_player(conn, @no_book)

      true ->
        take_book(conn, room_id)
    end
  end

  defp take_book(conn, room_id) do
    case Items.get(@book_item_id) do
      {:ok, _item} ->
        Room.put_state_by_id(room_id, @book_count_key, 0)

        conn
        |> Helpers.give_item(@book_item_id)
        |> Helpers.broadcast_vision(room_id, @took_book)
        |> announce_rumor(conn.character.name)

      _ ->
        Helpers.render_to_player(conn, @missing_item)
    end
  end

  # LPC: me->name(1) + "从少林寺窃走一本易筋经。"
  defp announce_rumor(conn, player_name) do
    Communication.announce("rumor", "#{player_name}从少林寺窃走一本#{@book_name}。")
    conn
  end

  # LPC `create()` 里 `set("status", 0)`
  defp status(room_id) do
    case Room.get_state_by_id(room_id, @status_key) do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  # LPC `create()` 里 `set("book_count", 1)`：房间 state 未播种时按「书还在」处理，
  # 避免漏配 UCL 的 `state` 块就让谜题永久失效。
  defp book_count(room_id) do
    case Room.get_state_by_id(room_id, @book_count_key) do
      value when is_integer(value) -> value
      _ -> 1
    end
  end
end

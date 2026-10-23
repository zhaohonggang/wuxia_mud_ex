defmodule Kantele.World.RoomActions.Changan.Xunbufang.Open do
  @moduledoc """
  `d/changan/xunbufang.c` 的 `do_open`（`add_action("do_open", "open")`）。

  LPC 原文：

      int do_open(string arg)
      {
          object me, key, nroom;
          me = this_player();
          if (! arg || arg != "door")
              return notify_fail("你要打开什么？\\n");

          if (! (key = present("laofang key", me)))
              return notify_fail("你没有开这道门的钥匙。\\n");

          if (! (nroom = find_object(__DIR__"laofang")))
                    nroom = load_object(__DIR__"laofang");

          set("exits/south", __DIR__"laofang");
          nroom->set("exits/north", __FILE__);
          message("vision", "只听喀嚓！一声，钥匙断了。好"
                      "在牢门已经开了。\\n", this_object() );
          me->set_temp("used_laofang_key", 1);
          destruct(key);
          return 1;
      }

  ## 移植要点

  - `present("laofang key", me)` → `Helpers.carries?/2`：钥匙物品在
    `changan.ucl` 里带别名 `laofang key` / `key`，`Kantele.World.Item.matches?/2`
    能命中。
  - `destruct(key)` → `Helpers.take_item/2`：从背包移除**第一件**匹配的实例并
    落盘。LPC 的 `destruct` 只毁 `present()` 拿到的那一件，语义一致。
  - `me->set_temp("used_laofang_key", 1)` → `meta.temp`（会话级，不落盘）。
    本批没有别的模块读它（LPC 里由后续剧情查询），照样写进去保持状态可观测。
  - **双向开门**：本房 `south` → `changan:laofang`，同时 `laofang` 的 `north` →
    本房。LPC 里 `nroom` 可能是 `load_object` 出来的新对象，本引擎房间进程恒在，
    无需判空。
  - `message("vision", msg, this_object())` 没有排除列表 → 全房播报（行动者也
    看到）。这里用 `Room.tell_room/2` 发纯文本：文案里没有 `$N`，不需要
    `VisionView` 渲染。
  - **没有「门已经开了」的守卫**（LPC 原样）：钥匙在手就能再开一次，再断一把。
  - `open` 是全局命令；本房 UCL 没有 `doors` 配置，遮蔽不损失既有功能。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @target_room "changan:laofang"
  @self_room "changan:xunbufang"
  @key_name "laofang key"
  @temp_key "used_laofang_key"

  @no_key "你没有开这道门的钥匙。\n"
  @key_broke "只听喀嚓！一声，钥匙断了。好在牢门已经开了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    case Map.get(conn, :character) do
      %{} = character when is_binary(room_id) ->
        cond do
          String.trim(arg) != "door" ->
            Helpers.render_to_player(conn, "你要打开什么？\n")

          not Helpers.carries?(character, @key_name) ->
            Helpers.render_to_player(conn, @no_key)

          true ->
            unlock(conn, room_id)
        end

      _ ->
        :not_handled
    end
  end

  defp unlock(conn, room_id) do
    Room.set_exit(room_id, "south", @target_room)
    Room.set_exit(@target_room, "north", @self_room)
    Room.tell_room(%Room{id: room_id}, @key_broke)

    # LPC 顺序：先 set_temp 再 destruct(key)；两者都不产生可见输出，顺序其实
    # 不可观测，这里照抄以免以后加逻辑时踩坑。
    {_removed?, conn} = conn |> mark_key_used() |> Helpers.take_item(@key_name)
    conn
  end

  # `me->set_temp("used_laofang_key", 1)`：`meta.temp` 只能由角色自己进程写，
  # 这里正是角色进程，直接 put_character 暂存即可。
  defp mark_key_used(conn) do
    character = current(conn)
    meta = PlayerMeta.put_temp(character.meta, @temp_key, 1)
    put_character(conn, %{character | meta: meta})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

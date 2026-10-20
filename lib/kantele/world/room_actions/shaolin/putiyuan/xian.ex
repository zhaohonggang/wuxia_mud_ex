defmodule Kantele.World.RoomActions.Shaolin.Putiyuan.Xian do
  @moduledoc """
  `d/shaolin/putiyuan.c` 的 `do_xian`（`add_action("do_xian", "xian")`）。

  LPC 原文：

      int do_xian(string arg)
      {
          int n;
          int right;
          object ob;

          if (! arg)
              return notify_fail("你要掀什么字？\\n");

          if (objectp(ob = present("xuanji dashi", this_object())) && living(ob))
              return notify_fail("玄寂一眼扫了过来，冷冰冰的似要将你看穿，你哪敢乱动？\\n");

          if (arg == "如")
              return notify_fail("你要掀哪一个如？\\n");

          if (sscanf(arg, "%s %d", arg, n) != 2) n = 1;
          if (strwidth(arg) != 2)
              return notify_fail("经偈中没有这个字呀！\\n");

          if (strsrch("一切有为法如梦幻泡影如露亦如电当作如是观", arg) == -1)
              return notify_fail("经偈中没有这个字呀！\\n");

          if (arg != "如" && n != 1 || n > 4)
              return notify_fail("经偈中没有这没多的“" + arg + "”字呀！\\n");

          message_vision("$N掀了一下" + (n > 1 ? "第" + chinese_number(n) + "个" : "") +
                          "“" + arg + "”字。\\n", this_player());

          right = 0;
          switch (query("status"))
          {
          case 1:
              if (arg == "梦") right = 2;
              break;
          case 2:
              if (arg == "如" && n == 3) right = 3;
              break;
          case 3:
              if (arg == "是") right = 4;
              break;
          }

          // 只要掀“一”就还原
          if (arg == "一") right = 1;
          set("status", right);
          message("vision", "你听到“咔啦”一声响声，似乎有什么机关触动了。\\n", this_object());
          if (right == 4)
          {
              message_vision("$N的手指还没有离开镜面，只听得轧轧声响，铜镜已"
                              "经缓缓翻起，露出一个小洞(hole)。\\n",
                              this_player());
              call_out("close_hole", 8);
          }
          return 1;
      }

  ## 谜题（源文件头注释）

      掀“一梦如是”：xian 一 → xian 梦 → xian 如 3 → xian 是

  「如」在经偈里出现三次，所以 `xian 如` 必须带序号，且**只有第三个**有效；
  `xian 一` 是重置键（任何时候都回到 status 1）。

  ## 移植要点

  - `query("status")` 是房间属性（`create()` 里 `set("status", 0)`），本实现存在
    房间 state 里，初值由 UCL `state = { status = 0  book_count = 1 }` 播种
    （见 `Kantele.World.Loader.parse_room/4`）。房间 state 缺失时按 `0` 处理。
  - `present("xuanji dashi", this_object()) && living(ob)`：玄寂在房间
    `private.characters` 里即为「在场且活着」（死亡的 NPC 会被移出房间）。
    别名表见 `clone_lib.ucl` 的 `characters "shaolin_xuan_ji"`。
  - `strwidth(arg) != 2`：LPC 的 `strwidth` 是**显示宽度**，一个汉字算 2。
    Elixir 侧等价判据是「恰好一个字符」（`String.length(arg) == 1`）；两者对
    「半角单字」的判定不同，但都会在随后的 `strsrch` 里落到同一句提示，结果一致。
  - `sscanf(arg, "%s %d", arg, n)`：解析 `如 3` 这种「字 + 序号」写法，缺序号时
    `n = 1`。
  - `call_out("close_hole", 8)`：**不能**用 `Room.set_timer/3` —— 它把
    `{:room_timer, ...}` 投给 `self()`（调用方），而房间进程没有对应
    `handle_info/2`（详见 `Kantele.World.Room.set_timer/3` 的说明）。这里改用
    `:timer.apply_after/4` 在独立进程里回调 `close_hole/1`，回调体只用按 room_id
    的运行时原语（`Room.put_state_by_id/3` + `Room.tell_room/2`），不需要 conn。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @status_key "status"
  @open_status 4

  # LPC `strsrch("一切有为法如梦幻泡影如露亦如电当作如是观", arg)` 的原句
  @verse "一切有为法如梦幻泡影如露亦如电当作如是观"

  @closed_message "一阵轧轧声过后，铜镜又缓缓的落下。\n"
  @click_message "你听到“咔啦”一声响声，似乎有什么机关触动了。\n"

  @no_arg "你要掀什么字？\n"
  @xuanji_watching "玄寂一眼扫了过来，冷冰冰的似要将你看穿，你哪敢乱动？\n"
  @which_ru "你要掀哪一个如？\n"
  @not_in_verse "经偈中没有这个字呀！\n"

  @chinese_numbers %{2 => "二", 3 => "三", 4 => "四"}

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    trimmed = String.trim(arg)

    cond do
      trimmed == "" ->
        Helpers.render_to_player(conn, @no_arg)

      xuanji_present?(room_id) ->
        Helpers.render_to_player(conn, @xuanji_watching)

      trimmed == "如" ->
        Helpers.render_to_player(conn, @which_ru)

      true ->
        reveal(conn, room_id, trimmed)
    end
  end

  defp reveal(conn, room_id, arg) do
    case parse(arg) do
      {:ok, char, n} ->
        case validate(char, n) do
          :ok ->
            status = status(room_id)
            next = next_status(status, char, n)

            conn
            |> Helpers.broadcast_vision(room_id, lift_message(char, n))
            |> put_status(room_id, next)
            |> Helpers.broadcast_vision(room_id, @click_message)
            |> open_hole(room_id, next)

          {:error, :too_many} ->
            Helpers.render_to_player(conn, too_many_message(char))

          {:error, _} ->
            Helpers.render_to_player(conn, @not_in_verse)
        end

      {:error, _} ->
        Helpers.render_to_player(conn, @not_in_verse)
    end
  end

  # `sscanf(arg, "%s %d", arg, n)`：`如 3` → {"如", 3}；`梦` → {"梦", 1}
  defp parse(arg) do
    case Regex.run(~r/^(\S+)(?:\s+(\d+))?$/u, arg) do
      [_, char] -> {:ok, char, 1}
      [_, char, count] -> {:ok, char, String.to_integer(count)}
      _ -> {:error, :not_in_verse}
    end
  end

  # LPC: `strwidth(arg) != 2` → 汉字一字；`strsrch(verse, arg) == -1` → 偈里没有；
  #      `(arg != "如" && n != 1) || n > 4` → 序号超范围。
  defp validate(char, n) do
    cond do
      String.length(char) != 1 -> {:error, :not_in_verse}
      not String.contains?(@verse, char) -> {:error, :not_in_verse}
      char != "如" and n != 1 -> {:error, :too_many}
      n > 4 -> {:error, :too_many}
      true -> :ok
    end
  end

  # LPC 原文的错别字「没多」照搬，不要「修」成「那么」—— 玩家看到的就是这句。
  defp too_many_message(char), do: "经偈中没有这没多的“#{char}”字呀！\n"

  defp lift_message(char, n) when n > 1 do
    "$N掀了一下第#{Map.get(@chinese_numbers, n, Integer.to_string(n))}个“#{char}”字。\n"
  end

  defp lift_message(char, _n), do: "$N掀了一下“#{char}”字。\n"

  # LPC switch：只有「当前状态 + 正确的下一个字」才推进，否则归零。
  # status 4（已掀开）没有 case，所以任何掀动都会把铜镜按回去。
  # 「只要掀“一”就还原」优先级高于 switch，故单独放在第一条子句。
  defp next_status(_status, "一", _n), do: 1
  defp next_status(1, "梦", _n), do: 2
  defp next_status(2, "如", 3), do: 3
  defp next_status(3, "是", _n), do: @open_status
  defp next_status(_status, _char, _n), do: 0

  defp open_hole(conn, _room_id, next) when next != @open_status, do: conn

  defp open_hole(conn, room_id, @open_status) do
    :timer.apply_after(8_000, __MODULE__, :close_hole, [room_id])

    Helpers.broadcast_vision(
      conn,
      room_id,
      "$N的手指还没有离开镜面，只听得轧轧声响，铜镜已经缓缓翻起，露出一个小洞(hole)。\n"
    )
  end

  defp put_status(conn, room_id, value) do
    Room.put_state_by_id(room_id, @status_key, value)
    conn
  end

  # LPC `create()` 里 `set("status", 0)`：房间 state 未播种时按 0（未掀开）处理。
  defp status(room_id) do
    case Room.get_state_by_id(room_id, @status_key) do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  # LPC `present("xuanji dashi", this_object()) && living(ob)`：死亡 NPC 会被移出
  # 房间的 `private.characters`，所以「在列表里」即「在场且活着」。
  defp xuanji_present?(room_id) do
    room_id
    |> Room.npc_characters_by_id()
    |> List.wrap()
    |> Enum.any?(&alias?(&1, "xuanji dashi"))
  end

  defp alias?(%{meta: %{aliases: aliases}}, name) when is_list(aliases), do: name in aliases
  defp alias?(_character, _name), do: false

  @doc """
  `call_out("close_hole", 8)`：8 秒后把 `status` 归零并向房间播报。

  由 `:timer.apply_after/4` 在**独立进程**里调用，因此拿不到 `conn` —— 全部走
  按 room_id 的运行时原语：`Room.put_state_by_id/3` 改状态、`Room.tell_room/2`
  广播（`{:room_message, ...}` 由角色进程的 Foreman 渲染）。房间进程已销毁时
  两者都安全降级（`put_state_by_id` 返回 `:error`，`tell_room` 广播给空列表）。

  与 LPC 一致：不取消上一次的 `call_out`，所以 8 秒内反复掀开铜镜会收到多次
  「铜镜又缓缓的落下」—— 每次回调只是把 status 再置 0，结果幂等。
  """
  def close_hole(room_id) when is_binary(room_id) do
    Room.put_state_by_id(room_id, @status_key, 0)
    Room.tell_room(%Room{id: room_id}, @closed_message)
    :ok
  end

  def close_hole(_room_id), do: :ok
end

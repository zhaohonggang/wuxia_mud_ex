defmodule Kantele.World.RoomActions.Emei.Shentan.Wang do
  @moduledoc """
  峨眉舍身崖下「深潭」三连房（`d/emei/st0.c`、`st1.c`、`st2.c`）的 `do_wang`
  （`add_action("do_wang", "wang")`）。

  LPC 原文（三房同形，只有 `st2` 的 north 多一个分支）：

      int do_wang()
      {
              object ob = this_player();

              message_vision(HIC "\\n$N" HIC "极目四望，发现还是有出路的，于"
                             "是求生试探之心大动。\\n"NOR, ob);

              switch (random(4))
              {
              case 0 : set("exits/east", __DIR__"st1"); break;
              case 1 : set("exits/east", __DIR__"st2"); break;
              case 2 : set("exits/east", __DIR__"st1"); break;
              default: set("exits/east", __DIR__"st2");
              }
              ... west / south / north 同形 ...
              remove_call_out("close_out");
              call_out("close_out", 3);
              return 1;
      }

      void close_out()
      {
              if (query("exits/east"))   delete("exits/east");
              if (query("exits/west"))   delete("exits/west");
              if (query("exits/south"))  delete("exits/south");
              if (query("exits/north"))  delete("exits/north");
      }

  ## 玩法

  玩家从舍身崖跌进臭水潭，四望（`wang`）才会**随机**冒出东南西北四个出口，指向
  `st1`/`st2` 两个相邻潭子；**3 秒后**全部自行消失。`st2` 的 north 有 1/4 概率指向
  `emei:ssyb`（舍身崖壁）—— 这是离开深潭的唯一真正出路，所以「四望」是脱困的唯一
  手段，反复试到出现 `ssyb` 为止。

  ## 移植要点

  - **四个方向各自独立 `random(4)`**：不是一次随机决定四个方向，而是四次独立抽样。
    所以同一轮可能出现「east 指 st1、west 也指 st1」，甚至（在 `st1` 房里）
    「east 指向 st1 自己」—— LPC 原样如此，这里照抄，不做去重/防自环。
  - **没有「已经开了」的守卫**：LPC 无条件 `set`，反复 `wang` 会无条件覆盖四个出口
    并重置 3 秒定时器（`remove_call_out` + `call_out`）。
  - **`close_out` 带 `if (query(...))` 守卫** → `DynamicExit.close_after/5` 的
    `only_if_open: true`；关闭时**不播报**（LPC 回调里没有 `message`）。
  - 三房共用本模块：出口表按 `room_id` 查 `@table`，未登记的房间返回 `:not_handled`。
  - `do_wang()` 不接收参数，`wang` 后面写什么都照样执行（LPC 同）。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @vision "\n$N极目四望，发现还是有出路的，于是求生试探之心大动。\n"

  @timer_key "exit_timer:close_out"
  @delay_ms 3_000
  @dirs ["east", "west", "south", "north"]

  # `switch (random(4))` 的四个分支，逐项照抄（索引 0..3，3 即 LPC 的 default）。
  @common %{
    "east" => ["emei:st1", "emei:st2", "emei:st1", "emei:st2"],
    "west" => ["emei:st1", "emei:st1", "emei:st2", "emei:st2"],
    "south" => ["emei:st2", "emei:st2", "emei:st1", "emei:st1"]
  }

  @north_plain ["emei:st2", "emei:st1", "emei:st2", "emei:st1"]
  # st2 的 north 第 0 分支是 `ssyb` —— 唯一能离开深潭的出口。
  @north_escape ["emei:ssyb", "emei:st1", "emei:st2", "emei:st1"]

  @table %{
    "emei:st0" => Map.put(@common, "north", @north_plain),
    "emei:st1" => Map.put(@common, "north", @north_plain),
    "emei:st2" => Map.put(@common, "north", @north_escape)
  }

  @impl true
  def run(conn, %{room_id: room_id}) do
    case Map.get(@table, room_id) do
      nil ->
        :not_handled

      table ->
        conn
        |> Helpers.broadcast_vision(room_id, @vision)
        |> reveal(room_id, table)
    end
  end

  defp reveal(conn, room_id, table) do
    # 四个方向各自 `random(4)`，互不相关（LPC 是四个独立 switch）。
    conn =
      Enum.reduce(@dirs, conn, fn dir, acc ->
        target = table |> Map.fetch!(dir) |> Enum.at(:rand.uniform(4) - 1)
        # 没有「已开」守卫：无条件覆盖。出口本身不产生文案，所以 vision 传空串。
        DynamicExit.open(acc, room_id, dir, target, "")
      end)

    DynamicExit.close_after(
      @delay_ms,
      room_id,
      @timer_key,
      Enum.map(@dirs, &{room_id, &1}),
      only_if_open: true
    )

    conn
  end
end

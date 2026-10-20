defmodule Kantele.World.RoomActions.Shaolin.PutiyuanTest.FakeRoom do
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{
         characters: Keyword.get(opts, :characters, []),
         item_instances: []
       }
     }}
  end
end

defmodule Kantele.World.RoomActions.Shaolin.PutiyuanTest do
  @moduledoc """
  P5-4h：少林菩提院「掀一梦如是 → 取易筋经」全链（`d/shaolin/putiyuan.c`）。

  - `look hole` → `Kantele.World.ItemDescHandlers.RoomStateTiers`（status + book_count 双键）
  - `xian <字> [序号]` → `...Putiyuan.Xian`（字序机关 + 8s `close_hole`）
  - `get book from hole` → `...Putiyuan.Get`（发 `clone_lib:yijinjing` + rumor）
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.ItemDescHandlers
  alias Kantele.World.ItemDescHandlers.RoomStateTiers
  alias Kantele.World.Items
  alias Kantele.World.Loader
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Shaolin.Putiyuan.Get
  alias Kantele.World.RoomActions.Shaolin.Putiyuan.Xian
  alias Kantele.World.RoomActions.Shaolin.PutiyuanTest.FakeRoom

  @room "shaolin:putiyuan"

  @hole_config %{
    "kind" => "room_state_tiers",
    "tiers" => [
      %{
        "match" => %{"status" => 4, "book_count" => 1},
        "text" => "这是铜镜下面的一个小洞，里面放着一本残破的旧经书(book)。"
      },
      %{
        "match" => %{"status" => 4, "book_count" => 0},
        "text" => "这是铜镜下面的一个小洞，里面空空如也，什么也没有。"
      },
      %{"text" => "哪里有什么洞？抓老鼠么？"}
    ]
  }

  @click "你听到“咔啦”一声响声，似乎有什么机关触动了。\n"
  @opened "{npc}的手指还没有离开镜面，只听得轧轧声响，铜镜已经缓缓翻起，露出一个小洞(hole)。\n"
  @closed "一阵轧轧声过后，铜镜又缓缓的落下。\n"

  setup do
    # 测试环境不加载世界数据（Items 缓存为空）。取书成功路径需要真实物品定义，
    # 这里注入与 `clone_lib.ucl` 的 `items "yijinjing"` 一致的一条。
    put_book()

    :ok
  end

  defp put_book do
    Items.put("clone_lib:yijinjing", %Kalevala.World.Item{
      id: "clone_lib:yijinjing",
      name: "易筋经",
      meta: %{}
    })
  end

  # ---- look hole -----------------------------------------------------------

  describe "look hole（RoomStateTiers）" do
    test "status 未到 4 → 哪里有什么洞" do
      assert hole_text(%{"status" => 0, "book_count" => 1}) == "哪里有什么洞？抓老鼠么？\n"
    end

    test "status 4 且 book_count 1 → 洞里放着经书" do
      assert hole_text(%{"status" => 4, "book_count" => 1}) ==
               "这是铜镜下面的一个小洞，里面放着一本残破的旧经书(book)。\n"
    end

    test "status 4 且 book_count 0 → 洞里空空如也" do
      assert hole_text(%{"status" => 4, "book_count" => 0}) ==
               "这是铜镜下面的一个小洞，里面空空如也，什么也没有。\n"
    end

    test "缺键不误命中：只有 status 没有 book_count 时落兜底" do
      assert hole_text(%{"status" => 4}) == "哪里有什么洞？抓老鼠么？\n"
    end

    test "跨房间读取走房间进程" do
      room_id = start_room(%{"status" => 4, "book_count" => 1})
      config = Map.put(@hole_config, "room_id", room_id)
      context = %Kalevala.World.Room.Context{data: %Room{id: "test:elsewhere"}}

      text =
        context
        |> RoomStateTiers.run(%{pid: self()}, %{config: config, room_id: "test:elsewhere"})
        |> context_output()

      assert text == "这是铜镜下面的一个小洞，里面放着一本残破的旧经书(book)。\n"
    end
  end

  test "lookup/2 注册了 room_state_tiers 与两个房间动作" do
    assert ItemDescHandlers.lookup(@room, "room_state_tiers") == {:ok, {RoomStateTiers, :run}}
    assert RoomActionHandlers.lookup(@room, "do_xian") == {:ok, {Xian, :run}}
    assert RoomActionHandlers.lookup(@room, "do_get") == {:ok, {Get, :run}}
  end

  describe "Loader 房间 state 播种（UCL `state = { ... }`）" do
    test "顶层键归一化为字符串，值原样保留（整数）" do
      {_key, room} =
        Loader.parse_room(
          %{id: "shaolin"},
          "putiyuan",
          %{
            name: "菩提院",
            description: "房",
            x: 0,
            y: 3,
            z: 1,
            state: %{status: 0, book_count: 1}
          },
          %{}
        )

      assert room.state == %{"status" => 0, "book_count" => 1}
    end

    test "无 state / 非 map → %{}（未回填房间行为不变）" do
      base = %{name: "n", description: "d", x: 0, y: 0, z: 0}

      assert {_k, r1} = Loader.parse_room(%{id: "z"}, "r", base, %{})
      assert r1.state == %{}

      assert {_k, r2} = Loader.parse_room(%{id: "z"}, "r", Map.put(base, :state, [1, 2]), %{})
      assert r2.state == %{}
    end
  end

  # ---- xian ----------------------------------------------------------------

  describe "xian（字序机关）" do
    test "无参数 → 你要掀什么字" do
      assert xian("", start_room()) |> output() == "你要掀什么字？\n"
    end

    test "玄寂在旁 → 不敢乱动" do
      chars = [%{id: "shaolin_xuan_ji", meta: %{aliases: ["xuanji dashi", "dashi"]}}]

      assert xian("梦", start_room(%{"status" => 0}, characters: chars)) |> output() ==
               "玄寂一眼扫了过来，冷冰冰的似要将你看穿，你哪敢乱动？\n"
    end

    test "只写“如” → 要求指定第几个" do
      assert xian("如", start_room()) |> output() == "你要掀哪一个如？\n"
    end

    test "偈里没有的字 → 经偈中没有这个字" do
      room_id = start_room()

      assert xian("天", room_id) |> output() == "经偈中没有这个字呀！\n"
      assert xian("如是我闻", room_id) |> output() == "经偈中没有这个字呀！\n"
    end

    test "非“如”字带序号 / 序号超范围 → 经偈中没有这没多的…" do
      room_id = start_room()

      assert xian("梦 2", room_id) |> output() == "经偈中没有这没多的“梦”字呀！\n"
      assert xian("如 5", room_id) |> output() == "经偈中没有这没多的“如”字呀！\n"
    end

    test "字序正确才推进：一 → 梦 → 如 3 → 是" do
      room_id = start_room()

      assert xian("一", room_id) |> published() == ["{npc}掀了一下“一”字。\n", @click]
      assert Room.get_state_by_id(room_id, "status") == 1

      xian("梦", room_id)
      assert Room.get_state_by_id(room_id, "status") == 2

      xian("如 3", room_id)
      assert Room.get_state_by_id(room_id, "status") == 3

      opened = xian("是", room_id)
      assert Room.get_state_by_id(room_id, "status") == 4

      assert published(opened) == ["{npc}掀了一下“是”字。\n", @click, @opened]
    end

    test "序号写错（如 2）→ 机关归零" do
      room_id = start_room(%{"status" => 2})

      assert xian("如 2", room_id) |> published() == ["{npc}掀了一下第二个“如”字。\n", @click]
      assert Room.get_state_by_id(room_id, "status") == 0
    end

    test "掀“一”随时还原" do
      room_id = start_room(%{"status" => 3})

      xian("一", room_id)
      assert Room.get_state_by_id(room_id, "status") == 1
    end

    test "铜镜已掀开时再掀任意字 → 按回去（status 归零）" do
      room_id = start_room(%{"status" => 4})

      xian("梦", room_id)
      assert Room.get_state_by_id(room_id, "status") == 0
    end
  end

  describe "close_hole/1（call_out 8s 回调）" do
    test "status 归零并向房间播报" do
      room_id = start_room(%{"status" => 4})

      :ok =
        Kantele.Communication.register("rooms:#{room_id}", Kantele.RoomChannel, room_id: room_id)

      :ok =
        Kantele.Communication.subscribe("rooms:#{room_id}",
          character: %Kalevala.Character{id: "p1", room_id: room_id}
        )

      assert :ok = Xian.close_hole(room_id)
      assert Room.get_state_by_id(room_id, "status") == 0
      assert_receive {:room_message, @closed}
    end

    test "房间进程不存在时安全降级" do
      assert :ok = Xian.close_hole("test:no_such_room")
    end
  end

  # ---- get -----------------------------------------------------------------

  describe "get book from hole" do
    test "目标串不匹配 → :not_handled（交回全局 get）" do
      room_id = start_room(%{"status" => 4, "book_count" => 1})

      assert Get.run(conn(), %{trailing: "sword", room_id: room_id}) == :not_handled
      assert Get.run(conn(), %{trailing: "book", room_id: room_id}) == :not_handled
      assert Get.run(conn(), %{trailing: "", room_id: room_id}) == :not_handled
    end

    test "洞没开 → :not_handled" do
      room_id = start_room(%{"status" => 0, "book_count" => 1})

      assert Get.run(conn(), %{trailing: "book from hole", room_id: room_id}) == :not_handled
    end

    test "书已被拿走 → 你想书想晕了头吗" do
      room_id = start_room(%{"status" => 4, "book_count" => 0})

      assert Get.run(conn(), %{trailing: "book from hole", room_id: room_id}) |> output() ==
               "你想书想晕了头吗？那里并没有什么书呀！\n"
    end

    test "四种写法都能取书：book_count 归零 + 进背包 + 房间播报" do
      for target <- ["book from hole", "book in hole", "jing from hole", "jing in hole"] do
        room_id = start_room(%{"status" => 4, "book_count" => 1})

        result = Get.run(conn(), %{trailing: target, room_id: room_id})

        assert Room.get_state_by_id(room_id, "book_count") == 0
        assert [%{item_id: "clone_lib:yijinjing"}] = character_of(result).inventory
        assert published(result) == ["{npc}从小洞中将那本经书取出，放进包内。\n"]
      end
    end

    test "物品定义缺失 → 系统故障提示，且不动 book_count" do
      Items.delete("clone_lib:yijinjing")
      room_id = start_room(%{"status" => 4, "book_count" => 1})

      assert Get.run(conn(), %{trailing: "book from hole", room_id: room_id}) |> output() ==
               "系统出现故障 - 找不到应该在这里的秘籍了 :)\n"

      assert Room.get_state_by_id(room_id, "book_count") == 1

      put_book()
    end
  end

  # ---- helpers -------------------------------------------------------------

  defp start_room(state \\ %{"status" => 0, "book_count" => 1}, opts \\ []) do
    room_id = "test:putiyuan-#{System.unique_integer([:positive])}"
    start_supervised!({FakeRoom, {room_id, [state: state] ++ opts}}, id: room_id)
    room_id
  end

  defp xian(arg, room_id) do
    Xian.run(conn(), %{verb: "xian", trailing: arg, room_id: room_id})
  end

  defp conn do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room,
        meta: %PlayerMeta{},
        inventory: []
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp hole_text(state) do
    context = %Kalevala.World.Room.Context{data: %Room{id: @room, state: state}}

    context
    |> RoomStateTiers.run(%{pid: self()}, %{config: @hole_config, room_id: @room})
    |> context_output()
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  # `channel_changes` 是**前插**列表（`Conn.publish_message/5` 用 `[change | list]`），
  # 真正下发前由 `Foreman.Channel.handle_channels/2` 统一 `Enum.reverse`。
  # 断言「玩家看到的先后」必须先还原成执行顺序。
  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end

  defp context_output(%{output: output}) do
    Enum.map_join(output, fn {_pid, %{data: data}} -> data end)
  end
end

defmodule Kantele.World.RoomActions.DynamicExitTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 的最小替身。

  `Kantele.World.Room.set_exit/3` 通过这个全局名找到房间进程，所以测试必须在真实
  房号上注册一个进程。**每个房号全模块只注册一次**（`setup_all` 里起、`reset/1`
  复位），不要按测试反复 stop/start —— `:global` 的名字注销是异步的，
  「停掉再起」在高并发全量跑里必然撞 `already started`。
  """

  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @doc "把房间复位成「空房间」：清空 exits / state，并取消遗留的自动关门定时器。"
  def reset(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, :reset)
      _ -> :ok
    end
  end

  @impl true
  def init({room_id, opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: Keyword.get(opts, :state, %{})},
       private: %{characters: [], item_instances: []}
     }}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    # `DynamicExit.close_after/5` 把 TRef 存成 `state["exit_timer:<key>"]`；
    # 房间进程比测试活得久，不复位就会让上一个测试的定时器打到下一个测试里。
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok, %{state | data: %Kantele.World.Room{id: state.data.id, state: %{}}}}
  end
end

defmodule Kantele.World.RoomActions.DynamicExitTest do
  @moduledoc """
  P5-4ae：动态出口（`set/delete("exits/<dir>")`）消费端首批。

  - `DynamicExit` 原语：判在 / 开 / 关 / 切换 / 定时关（含 `only_if_open` 与取消）。
  - 六间房的 handler：`changan:xunbufang`、`guanwai:xiuxishi`、
    `huashan:xiuxishi`、`lingxiao:shanya`、`foshan:pm_restroom`、
    `meizhuang:didao3`。

  handler 里的房间 id 是写死的真实 id（`changan:laofang` 等），所以这里也只能用真实
  id 注册 `FakeRoom`。`@room_ids` 里的每个房号在 `setup_all` 起一次、每个测试前
  `reset/1` 复位；`async: false` 保证本模块内部不并发。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Communication
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Changan.Xunbufang
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.DynamicExitTest.FakeRoom
  alias Kantele.World.RoomActions.Foshan.PmRestroom
  alias Kantele.World.RoomActions.Guanwai.Xiuxishi
  alias Kantele.World.RoomActions.Huashan.Xiuxishi, as: HuashanXiuxishi
  alias Kantele.World.RoomActions.Lingxiao.Shanya
  alias Kantele.World.RoomActions.Meizhuang.Didao3

  # 本模块用到的全部房号。前 8 个是原语测试的隔离房，其余是 handler 写死的真实 id。
  @room_ids [
    "test:exit-primitive-1",
    "test:exit-primitive-2",
    "test:exit-primitive-3",
    "test:exit-primitive-4",
    "test:exit-primitive-5",
    "test:exit-primitive-6",
    "test:exit-primitive-7",
    "test:exit-primitive-8",
    "changan:laofang",
    "changan:xunbufang",
    "guanwai:jingxiu",
    "guanwai:xiuxishi",
    "huashan:xiaolu2",
    "huashan:xiuxishi",
    "lingxiao:shanya",
    "foshan:pm_restroom",
    "meizhuang:didao3"
  ]

  setup_all do
    pids =
      for room_id <- @room_ids do
        # 保险：万一有残留（例如上一次跑留下的同名进程）先让出名字。
        :global.unregister_name({Kalevala.World.Room, room_id})
        {:ok, pid} = FakeRoom.start_link({room_id, []})
        pid
      end

    on_exit(fn ->
      Enum.each(pids, fn pid ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)
    end)

    :ok
  end

  setup do
    Enum.each(@room_ids, &FakeRoom.reset/1)
    :ok
  end

  # ---- DynamicExit 原语 ------------------------------------------------------

  describe "DynamicExit 原语" do
    test "open?/2 初始为 false，open/5 后为 true 并广播 vision" do
      room = start_room("test:exit-primitive-1")

      refute DynamicExit.open?(room, "north")

      conn = DynamicExit.open(conn(room), room, "north", "test:target", "$N推开了石门。\n")

      assert DynamicExit.open?(room, "north")
      assert published(conn) == ["{npc}推开了石门。\n"]
    end

    test "close/4 移除出口并广播" do
      room = start_room("test:exit-primitive-2")
      DynamicExit.open(conn(room), room, "north", "test:target", "")

      conn = DynamicExit.close(conn(room), room, "north", "$N把门关上了。\n")

      refute DynamicExit.open?(room, "north")
      assert published(conn) == ["{npc}把门关上了。\n"]
    end

    test "toggle/6 没开就开、已开就关" do
      room = start_room("test:exit-primitive-3")

      conn = DynamicExit.toggle(conn(room), room, "down", "test:target", "开了。\n", "关了。\n")
      assert DynamicExit.open?(room, "down")
      assert published(conn) == ["开了。\n"]

      conn = DynamicExit.toggle(conn(room), room, "down", "test:target", "开了。\n", "关了。\n")
      refute DynamicExit.open?(room, "down")
      assert published(conn) == ["关了。\n"]
    end

    test "do_close_after/1 删出口并向房间播报" do
      room = start_room("test:exit-primitive-4")
      DynamicExit.open(conn(room), room, "north", "test:target", "")
      subscribe_room(room)

      :ok = DynamicExit.do_close_after([{room, "north", "门自己合上了。\n"}])

      refute DynamicExit.open?(room, "north")
      assert_receive {:room_message, "门自己合上了。\n"}, 500
    end

    test "do_close_after/2 的 only_if_open 为 true 时跳过已关的出口" do
      room = start_room("test:exit-primitive-5")
      subscribe_room(room)

      :ok = DynamicExit.do_close_after([{room, "north", "门自己合上了。\n"}], true)

      refute_receive {:room_message, _}, 100
    end

    test "close_after/4 到点触发" do
      room = start_room("test:exit-primitive-6")
      DynamicExit.open(conn(room), room, "north", "test:target", "")
      subscribe_room(room)

      :ok = DynamicExit.close_after(20, room, "exit_timer:t", [{room, "north", "关。\n"}])

      assert_receive {:room_message, "关。\n"}, 500
      refute DynamicExit.open?(room, "north")
    end

    test "cancel_close/2 能取消尚未触发的定时器" do
      room = start_room("test:exit-primitive-7")
      DynamicExit.open(conn(room), room, "north", "test:target", "")
      subscribe_room(room)

      :ok = DynamicExit.close_after(50, room, "exit_timer:t", [{room, "north", "关。\n"}])
      :ok = DynamicExit.cancel_close(room, "exit_timer:t")

      refute_receive {:room_message, _}, 200
      assert DynamicExit.open?(room, "north")
    end

    test "close_after/4 重复调用只保留最后一个定时器" do
      room = start_room("test:exit-primitive-8")
      DynamicExit.open(conn(room), room, "north", "test:target", "")
      subscribe_room(room)

      :ok = DynamicExit.close_after(30, room, "exit_timer:t", [{room, "north", "关。\n"}])
      :ok = DynamicExit.close_after(60, room, "exit_timer:t", [{room, "north", "关。\n"}])

      assert_receive {:room_message, "关。\n"}, 500
      refute_receive {:room_message, _}, 200
    end
  end

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "六间房的 handler 都指向对应模块" do
      assert RoomActionHandlers.lookup("changan:xunbufang", "do_open") ==
               {:ok, {Xunbufang.Open, :run}}

      assert RoomActionHandlers.lookup("guanwai:xiuxishi", "do_open") ==
               {:ok, {Xiuxishi.Open, :run}}

      assert RoomActionHandlers.lookup("guanwai:xiuxishi", "do_close") ==
               {:ok, {Xiuxishi.Close, :run}}

      assert RoomActionHandlers.lookup("huashan:xiuxishi", "do_open") ==
               {:ok, {HuashanXiuxishi.Open, :run}}

      assert RoomActionHandlers.lookup("huashan:xiuxishi", "do_close") ==
               {:ok, {HuashanXiuxishi.Close, :run}}

      assert RoomActionHandlers.lookup("lingxiao:shanya", "do_open") ==
               {:ok, {Shanya.Open, :run}}

      assert RoomActionHandlers.lookup("foshan:pm_restroom", "do_open") ==
               {:ok, {PmRestroom.Open, :run}}

      assert RoomActionHandlers.lookup("foshan:pm_restroom", "do_close") ==
               {:ok, {PmRestroom.Close, :run}}

      # UCL 里 `pull = "do_open"`：动词是 pull，handler 名是 do_open
      assert RoomActionHandlers.lookup("meizhuang:didao3", "do_open") ==
               {:ok, {Didao3.Pull, :run}}
    end
  end

  # ---- changan:xunbufang -----------------------------------------------------

  describe "changan:xunbufang（用钥匙开牢门）" do
    test "参数不是 door → 你要打开什么" do
      room = xunbufang_room()

      assert output(Xunbufang.Open.run(conn(room), params("pen", room))) ==
               "你要打开什么？\n"
    end

    test "没有钥匙 → 你没有开这道门的钥匙" do
      room = xunbufang_room()

      assert output(Xunbufang.Open.run(conn(room), params("door", room))) ==
               "你没有开这道门的钥匙。\n"
    end

    test "有钥匙 → 两边开门、钥匙消失、记 temp" do
      room = xunbufang_room()
      subscribe_room(room)

      result = Xunbufang.Open.run(conn(room, inventory: [key()]), params("door", room))

      assert Room.has_exit_by_id?(room, "south")
      assert Room.has_exit_by_id?("changan:laofang", "north")
      assert character_of(result).inventory == []
      assert character_of(result).meta.temp["used_laofang_key"] == 1
      assert_receive {:room_message, "只听喀嚓！一声，钥匙断了。好在牢门已经开了。\n"}, 500
    end
  end

  # ---- guanwai:xiuxishi ------------------------------------------------------

  describe "guanwai:xiuxishi（双向门 + 10 秒自动关）" do
    test "参数不认识 → 你要开什么" do
      room = guanwai_rooms()

      assert output(Xiuxishi.Open.run(conn(room), params("window", room))) ==
               "你要开什么？\n"
    end

    test "开门：两边出口都开、邻居房看到「梆地一声」" do
      room = guanwai_rooms()
      subscribe_room("guanwai:jingxiu")

      result = Xiuxishi.Open.run(conn(room, name: "张三"), params("door", room))

      assert Room.has_exit_by_id?(room, "north")
      assert Room.has_exit_by_id?("guanwai:jingxiu", "south")
      assert published(result) == ["{npc}轻手轻脚地把门打开。\n"]
      assert_receive {:room_message, "梆地一声，张三从里面把门打开，一脸的不耐烦。\n"}, 500
    end

    test "睡过的人开门 → 邻居房看到「精神焕发」" do
      room = guanwai_rooms()
      subscribe_room("guanwai:jingxiu")

      meta = PlayerMeta.put_temp(%PlayerMeta{temp: %{}}, "sleeped", true)
      _result = Xiuxishi.Open.run(conn(room, name: "张三", meta: meta), params("door", room))

      assert_receive {:room_message, "吱地一声，张三精神焕发地从里面把门打开了。\n"}, 500
    end

    test "已经开着 → 大门已经是开着了" do
      room = guanwai_rooms()
      DynamicExit.open(conn(room), room, "north", "guanwai:jingxiu", "")

      assert output(Xiuxishi.Open.run(conn(room), params("door", room))) ==
               "大门已经是开着了。\n"
    end

    test "关门：两边都关、邻居房看到「门被人从里面关上了了」" do
      room = guanwai_rooms()
      DynamicExit.open(conn(room), room, "north", "guanwai:jingxiu", "")
      Room.set_exit("guanwai:jingxiu", "south", room)
      subscribe_room("guanwai:jingxiu")

      result = Xiuxishi.Close.run(conn(room), params("door", room))

      refute Room.has_exit_by_id?(room, "north")
      refute Room.has_exit_by_id?("guanwai:jingxiu", "south")
      assert published(result) == ["{npc}轻手轻脚的把门关上了。\n"]
      assert_receive {:room_message, "门被人从里面关上了了。\n"}, 500
    end

    test "关着时关门 → 门已经是关着的了" do
      room = guanwai_rooms()

      assert output(Xiuxishi.Close.run(conn(room), params("door", room))) ==
               "门已经是关着的了。\n"
    end

    test "关门的参数不认 north（LPC 只认 men/door）" do
      room = guanwai_rooms()

      assert output(Xiuxishi.Close.run(conn(room), params("north", room))) ==
               "你要关什么？\n"
    end
  end

  # ---- huashan:xiuxishi ------------------------------------------------------

  describe "huashan:xiuxishi（双向门 + 10 秒自动关）" do
    test "开门：west/east 两边都开" do
      room = huashan_rooms()

      _result = HuashanXiuxishi.Open.run(conn(room), params("west", room))

      assert Room.has_exit_by_id?(room, "west")
      assert Room.has_exit_by_id?("huashan:xiaolu2", "east")
    end

    test "参数不是 men/door/west → 你要开什么" do
      room = huashan_rooms()

      assert output(HuashanXiuxishi.Open.run(conn(room), params("south", room))) ==
               "你要开什么？\n"
    end

    test "已经开着 → 大门已经是开着了" do
      room = huashan_rooms()
      DynamicExit.open(conn(room), room, "west", "huashan:xiaolu2", "")

      assert output(HuashanXiuxishi.Open.run(conn(room), params("door", room))) ==
               "大门已经是开着了。\n"
    end

    test "关门：west/east 都关" do
      room = huashan_rooms()
      DynamicExit.open(conn(room), room, "west", "huashan:xiaolu2", "")
      Room.set_exit("huashan:xiaolu2", "east", room)

      result = HuashanXiuxishi.Close.run(conn(room), params("men", room))

      refute Room.has_exit_by_id?(room, "west")
      refute Room.has_exit_by_id?("huashan:xiaolu2", "east")
      assert published(result) == ["{npc}一伸手，把门关上了。\n"]
    end
  end

  # ---- lingxiao:shanya -------------------------------------------------------

  describe "lingxiao:shanya（放吊桥）" do
    test "参数不是 bridge → 你要干嘛" do
      room = start_room("lingxiao:shanya")

      assert output(Shanya.Open.run(conn(room), params("door", room))) == "你要干嘛？\n"
    end

    test "open bridge → 开 north 出口并连播两句" do
      room = start_room("lingxiao:shanya")

      result = Shanya.Open.run(conn(room), params("bridge", room))

      assert Room.has_exit_by_id?(room, "north")

      assert published(result) == [
               "\n{npc}运足力气，大叫一声：“开门呀！”\n",
               "只听得城上有人说道：“有人来了，放吊桥吧。”\n\n" <>
                 "只听得“轧轧轧”响了片刻，吊桥缓缓放下，露出一个方方正正的城门来。\n"
             ]
    end

    test "反复放桥不会报错（LPC 没有「已经开了」守卫）" do
      room = start_room("lingxiao:shanya")

      assert Shanya.Open.run(conn(room), params("bridge", room)) != nil
      assert Shanya.Open.run(conn(room), params("bridge", room)) != nil
      assert Room.has_exit_by_id?(room, "north")
    end
  end

  # ---- foshan:pm_restroom ----------------------------------------------------

  describe "foshan:pm_restroom（管理员开关拍卖会大门）" do
    test "普通玩家 → :not_handled（交回全局 open/close）" do
      room = start_room("foshan:pm_restroom")

      assert PmRestroom.Open.run(conn(room), params("door", room)) == :not_handled
      assert PmRestroom.Close.run(conn(room), params("door", room)) == :not_handled
    end

    test "管理员开门 → 开 south 出口 + 本人提示" do
      room = start_room("foshan:pm_restroom")

      result = PmRestroom.Open.run(conn(room, wiz_level: 3), params("door", room))

      assert Room.has_exit_by_id?(room, "south")
      assert published(result) == ["{npc}轻轻一推，将通向英雄会馆的小门开启了。\n"]
      assert output(result) == "你开通了店铺拍卖会的路径。\n"
    end

    test "管理员重复开门 → 门已经是开着的了" do
      room = start_room("foshan:pm_restroom")
      DynamicExit.open(conn(room), room, "south", "foshan:pmc", "")

      assert output(PmRestroom.Open.run(conn(room, wiz_level: 3), params("door", room))) ==
               "门已经是开着的了。\n"
    end

    test "管理员关门 → 关 south 出口" do
      room = start_room("foshan:pm_restroom")
      DynamicExit.open(conn(room), room, "south", "foshan:pmc", "")

      result = PmRestroom.Close.run(conn(room, wiz_level: 3), params("door", room))

      refute Room.has_exit_by_id?(room, "south")
      assert published(result) == ["{npc}顺手一带，将通向拍卖后厅的小门关上了。\n"]
    end
  end

  # ---- meizhuang:didao3 ------------------------------------------------------

  describe "meizhuang:didao3（拉木板，动词 pull）" do
    test "空参数 → 你要打开什么" do
      room = start_room("meizhuang:didao3")

      assert output(Didao3.Pull.run(conn(room), params("", room))) == "你要打开什么？\n"
    end

    test "目标不是 floor → 你没法打开 X 这样东西" do
      room = start_room("meizhuang:didao3")

      assert output(Didao3.Pull.run(conn(room), params("door", room))) ==
               "你没法打开 door 这样东西。\n"
    end

    test "pull floor → 开 down 出口 + 播报" do
      room = start_room("meizhuang:didao3")

      result = Didao3.Pull.run(conn(room), params("floor", room))

      assert Room.has_exit_by_id?(room, "down")
      assert published(result) == ["{npc}拉起地上的木板，发现下面是空的。\n"]
    end

    test "已经拉开 → 地上的木板现在已经拉开了" do
      room = start_room("meizhuang:didao3")
      DynamicExit.open(conn(room), room, "down", "meizhuang:didao4", "")

      assert output(Didao3.Pull.run(conn(room), params("floor", room))) ==
               "地上的木板现在已经拉开了。\n"
    end
  end

  # ---- helpers ---------------------------------------------------------------

  defp params(arg, room_id), do: %{verb: "open", trailing: arg, room_id: room_id}

  # 房间由 `setup_all` 统一注册、`setup` 统一复位，这里只是保留调用点的可读性。
  defp start_room(room_id) do
    true = room_id in @room_ids
    room_id
  end

  defp xunbufang_room do
    start_room("changan:laofang")
    start_room("changan:xunbufang")
  end

  defp guanwai_rooms do
    start_room("guanwai:jingxiu")
    start_room("guanwai:xiuxishi")
  end

  defp huashan_rooms do
    start_room("huashan:xiaolu2")
    start_room("huashan:xiuxishi")
  end

  # `Kantele.RoomChannel.subscribe_request/3` 会校验 `options[:character].room_id`
  # 与频道 `config[:room_id]` 一致，所以订阅时必须带上同房间的 character。
  defp subscribe_room(room_id) do
    channel = "rooms:#{room_id}"

    case Communication.register(channel, Kantele.RoomChannel, room_id: room_id) do
      :ok -> :ok
      {:error, :already_registered} -> :ok
    end

    :ok =
      Communication.subscribe(channel,
        character: %Kalevala.Character{id: "test-subscriber", room_id: room_id}
      )
  end

  defp conn(room_id, opts \\ []) do
    character = %Kalevala.Character{
      id: Keyword.get(opts, :id, "test-player"),
      name: Keyword.get(opts, :name, "玩家"),
      room_id: room_id,
      attributes: %{"wiz_level" => Keyword.get(opts, :wiz_level, 0)},
      meta: Keyword.get(opts, :meta, %PlayerMeta{temp: %{}}),
      inventory: Keyword.get(opts, :inventory, [])
    }

    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  # `d/changan/npc/obj/laofang-key.c`：`set_name(HIC "牢房钥匙" NOR, ({"laofang key","key"}))`
  defp key do
    %Kalevala.World.Item.Instance{
      id: "test-key-instance",
      item_id: "changan:laofang_key",
      item: %Kalevala.World.Item{
        id: "changan:laofang_key",
        name: "牢房钥匙",
        meta: %{aliases: ["laofang key", "key"]}
      }
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end
end

defmodule Kantele.World.RoomActions.DoPushTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 DoBreakTest.FakeRoom）。

  全模块只注册一次（`setup_all` 起、`setup` 复位）。额外提供 `set_occupants/2`
  模拟邻居房有人（等价 LPC `person_inside`），供 guanwai:jingxiu / huashan:xiaolu2
  的「门从里面闩上了」分支使用。
  """
  use GenServer

  def start_link({room_id, opts}) do
    GenServer.start_link(__MODULE__, {room_id, opts},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  def reset(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, :reset)
      _ -> :ok
    end
  end

  def set_occupants(room_id, chars) when is_list(chars) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, {:set_occupants, chars})
      _ -> :ok
    end
  end

  @impl true
  def init({room_id, _opts}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok,
     %{
       data: %Kantele.World.Room{id: state.data.id, state: %{}},
       private: %{characters: [], item_instances: []}
     }}
  end

  def handle_call({:set_occupants, chars}, _from, state) do
    {:reply, :ok, %{state | private: %{state.private | characters: chars}}}
  end
end

defmodule Kantele.World.RoomActions.DoPushTest do
  @moduledoc """
  P5-4aj：`do_push` 推门/推石壁/推草丛/推大床 一批（8 个房间）的移植测试。

  覆盖点：
  - 注册：8 房都挂 `do_push`（注册表断言见 `room_action_handlers_test.exs`）。
  - 参数守卫：错词 → `:not_handled`（放行全局 push）；识别词但已开 → 提示。
  - 邻居占用（person_inside 等价）：门从里面闩上，不开门。
  - 内力 / 最大内力 / 臂力 门控：成功开门 + 扣内力；失败内力清零（部分）或仅提示。
  - 双向门：自房出口 + 邻居反向出口都打开，10 秒后双向自关。
  - 定时关：成功开门登记定时器，`do_close_after` 关出口（+ 播报）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.DoPushTest.FakeRoom

  alias Kantele.World.RoomActions.Guanwai.Jingxiu.Push, as: GuanwaiJingxiu
  alias Kantele.World.RoomActions.Huashan.Xiaolu2.Push, as: HuashanXiaolu2
  alias Kantele.World.RoomActions.Hengyang.Liufugate.Push, as: HengyangLiufugate
  alias Kantele.World.RoomActions.Lingxiao.Didi.Push, as: LingxiaoDidi
  alias Kantele.World.RoomActions.Wanjiegu.Entrance.Push, as: WanjieguEntrance
  alias Kantele.World.RoomActions.Xiakedao.Dating.Push, as: XiakedaoDating
  alias Kantele.World.RoomActions.Xiakedao.Yadi.Push, as: XiakedaoYadi
  alias Kantele.World.RoomActions.Changan.Qunyuys8.Push, as: ChanganQunyuys8

  @self_rooms [
    "guanwai:jingxiu",
    "huashan:xiaolu2",
    "hengyang:liufugate",
    "lingxiao:didi",
    "wanjiegu:entrance",
    "xiakedao:dating",
    "xiakedao:yadi",
    "changan:qunyuys8"
  ]
  @neighbor_rooms ["guanwai:xiuxishi", "huashan:xiuxishi"]
  @room_ids @self_rooms ++ @neighbor_rooms

  setup_all do
    pids =
      for room_id <- @room_ids do
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

  # ---- 注册表（8 房都挂 do_push）----

  describe "注册表" do
    test "8 个房间都挂了 do_push" do
      for room_id <- @self_rooms do
        assert RoomActionHandlers.registered?(room_id, "do_push")
      end
    end
  end

  # ---- guanwai:jingxiu（men/door，双向门 + 邻居占用，10s 关）----

  describe "guanwai:jingxiu" do
    test "错词 → :not_handled（放行全局 push）" do
      assert GuanwaiJingxiu.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "window")) ==
               :not_handled
    end

    test "已开 → 提示「门已经是开着了」" do
      DynamicExit.open(conn("guanwai:jingxiu"), "guanwai:jingxiu", "south", "guanwai:xiuxishi", "")
      conn = GuanwaiJingxiu.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "men"))
      assert output_text(conn) =~ "门已经是开着了"
    end

    test "邻居有人（person_inside 等价）→ 门从里面闩上了，不开门" do
      FakeRoom.set_occupants("guanwai:xiuxishi", [%{id: "someone"}])
      conn = GuanwaiJingxiu.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "men"))
      assert published(conn) |> Enum.any?(&(&1 =~ "门被人从里面闩上了"))
      refute DynamicExit.open?("guanwai:jingxiu", "south")
    end

    test "正常推开 → 双向门开 + 10s 定时器" do
      subscribe_room("guanwai:jingxiu")
      subscribe_room("guanwai:xiuxishi")
      GuanwaiJingxiu.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "men"))

      assert DynamicExit.open?("guanwai:jingxiu", "south")
      assert exit_target("guanwai:jingxiu", "south") == "guanwai:xiuxishi"
      assert DynamicExit.open?("guanwai:xiuxishi", "north")
      assert exit_target("guanwai:xiuxishi", "north") == "guanwai:jingxiu"
      assert {:once, _ref} = Room.get_state_by_id("guanwai:jingxiu", "exit_timer:push")
    end

    test "10 秒后双向自关（do_close_after 模拟超时）" do
      subscribe_room("guanwai:jingxiu")
      subscribe_room("guanwai:xiuxishi")
      GuanwaiJingxiu.run(conn("guanwai:jingxiu"), params("guanwai:jingxiu", "men"))
      flush_room_messages()

      DynamicExit.do_close_after(
        [
          {"guanwai:jingxiu", "south", "门咿咿呀呀地自己合上了。\n"},
          {"guanwai:xiuxishi", "north", "门咿咿呀呀地自己合上了。\n"}
        ],
        false
      )

      refute DynamicExit.open?("guanwai:jingxiu", "south")
      refute DynamicExit.open?("guanwai:xiuxishi", "north")
      assert_received {:room_message, msg}, 200
      assert msg =~ "自己合上了"
    end
  end

  # ---- huashan:xiaolu2（men/door，east/west 双向门，10s 关）----

  describe "huashan:xiaolu2" do
    test "错词 → :not_handled" do
      assert HuashanXiaolu2.run(conn("huashan:xiaolu2"), params("huashan:xiaolu2", "wall")) ==
               :not_handled
    end

    test "邻居有人 → 门从里面闩上了，不开门" do
      FakeRoom.set_occupants("huashan:xiuxishi", [%{id: "someone"}])
      conn = HuashanXiaolu2.run(conn("huashan:xiaolu2"), params("huashan:xiaolu2", "men"))
      assert published(conn) |> Enum.any?(&(&1 =~ "门被人从里面闩上了"))
      refute DynamicExit.open?("huashan:xiaolu2", "east")
    end

    test "正常推开 → 双向门开（east/west）+ 10s 定时器" do
      HuashanXiaolu2.run(conn("huashan:xiaolu2"), params("huashan:xiaolu2", "door"))
      assert DynamicExit.open?("huashan:xiaolu2", "east")
      assert exit_target("huashan:xiaolu2", "east") == "huashan:xiuxishi"
      assert DynamicExit.open?("huashan:xiuxishi", "west")
      assert exit_target("huashan:xiuxishi", "west") == "huashan:xiaolu2"
      assert {:once, _ref} = Room.get_state_by_id("huashan:xiaolu2", "exit_timer:push")
    end
  end

  # ---- hengyang:liufugate（gate，需 marks 临时标记，5s 关）----

  describe "hengyang:liufugate" do
    test "无 marks → 提示「门关得牢牢的」，不开门" do
      conn = HengyangLiufugate.run(conn("hengyang:liufugate"), params("hengyang:liufugate", "gate"))
      assert output_text(conn) =~ "门关得牢牢的"
      refute DynamicExit.open?("hengyang:liufugate", "enter")
    end

    test "错词 ≠ gate → :not_handled" do
      assert HengyangLiufugate.run(conn("hengyang:liufugate", temp: %{"marks/liufu" => 1}),
               params("hengyang:liufugate", "door")) == :not_handled
    end

    test "有 marks → 开 enter→hengyang:liufudayuan、5s 定时器" do
      HengyangLiufugate.run(conn("hengyang:liufugate", temp: %{"marks/liufu" => 1}),
        params("hengyang:liufugate", "gate")
      )

      assert DynamicExit.open?("hengyang:liufugate", "enter")
      assert exit_target("hengyang:liufugate", "enter") == "hengyang:liufudayuan"
      assert {:once, _ref} = Room.get_state_by_id("hengyang:liufugate", "exit_timer:push")
    end
  end

  # ---- lingxiao:didi（无参，max_neili>=500，5s 关）----

  describe "lingxiao:didi" do
    test "max_neili < 500 → 提示「纹丝不动」，不开门" do
      conn = LingxiaoDidi.run(conn("lingxiao:didi", max_neili: 400), params("lingxiao:didi"))
      assert published(conn) |> Enum.any?(&(&1 =~ "纹丝不动"))
      refute DynamicExit.open?("lingxiao:didi", "enter")
    end

    test "max_neili >= 500 → 开 enter→lingxiao:dilao、5s 定时器" do
      LingxiaoDidi.run(conn("lingxiao:didi", max_neili: 600), params("lingxiao:didi"))
      assert DynamicExit.open?("lingxiao:didi", "enter")
      assert exit_target("lingxiao:didi", "enter") == "lingxiao:dilao"
      assert {:once, _ref} = Room.get_state_by_id("lingxiao:didi", "exit_timer:push")
    end
  end

  # ---- wanjiegu:entrance（草丛/grass，10s 关）----

  describe "wanjiegu:entrance" do
    test "错词 → :not_handled" do
      assert WanjieguEntrance.run(conn("wanjiegu:entrance"), params("wanjiegu:entrance", "tree")) ==
               :not_handled
    end

    test "草丛 → 开 enter→wanjiegu:tree_hole、10s 定时器" do
      WanjieguEntrance.run(conn("wanjiegu:entrance"), params("wanjiegu:entrance", "草丛"))
      assert DynamicExit.open?("wanjiegu:entrance", "enter")
      assert exit_target("wanjiegu:entrance", "enter") == "wanjiegu:tree_hole"
      assert {:once, _ref} = Room.get_state_by_id("wanjiegu:entrance", "exit_timer:push")
    end
  end

  # ---- xiakedao:dating（pingfeng，neili>=100 开屏风后甬道、扣 100，5s 关）----

  describe "xiakedao:dating" do
    test "错词 → 提示「你要推什么呀」，恒 handle" do
      conn = XiakedaoDating.run(conn("xiakedao:dating"), params("xiakedao:dating", "wall"))
      assert output_text(conn) =~ "你要推什么呀"
      refute DynamicExit.open?("xiakedao:dating", "south")
    end

    test "neili < 100 → 内力清零、不开门" do
      conn = XiakedaoDating.run(conn("xiakedao:dating", neili: 50), params("xiakedao:dating", "pingfeng"))
      assert neili_of(conn) == 0
      refute DynamicExit.open?("xiakedao:dating", "south")
    end

    test "neili >= 100 → 开 south→xiakedao:yongdao3、扣 100、5s 定时器" do
      conn =
        XiakedaoDating.run(conn("xiakedao:dating", neili: 300),
          params("xiakedao:dating", "pingfeng")
        )

      assert DynamicExit.open?("xiakedao:dating", "south")
      assert exit_target("xiakedao:dating", "south") == "xiakedao:yongdao3"
      assert neili_of(conn) == 200
      assert {:once, _ref} = Room.get_state_by_id("xiakedao:dating", "exit_timer:push")
    end
  end

  # ---- xiakedao:yadi（men，需 yadi_swim + neili>150，扣 150，5s 关）----

  describe "xiakedao:yadi" do
    test "错词 → 提示「你想推什么呀」" do
      conn = XiakedaoYadi.run(conn("xiakedao:yadi", temp: %{"yadi_swim" => true}), params("xiakedao:yadi", "wall"))
      assert output_text(conn) =~ "你想推什么呀"
      refute DynamicExit.open?("xiakedao:yadi", "west")
    end

    test "无 yadi_swim → 提示「你想推什么呀」，不开门" do
      conn = XiakedaoYadi.run(conn("xiakedao:yadi"), params("xiakedao:yadi", "men"))
      assert output_text(conn) =~ "你想推什么呀"
      refute DynamicExit.open?("xiakedao:yadi", "west")
    end

    test "neili <= 150 → 内力清零、不开门（yadi_swim 被消费）" do
      conn =
        XiakedaoYadi.run(conn("xiakedao:yadi", neili: 150, temp: %{"yadi_swim" => true}),
          params("xiakedao:yadi", "men")
        )

      assert neili_of(conn) == 0
      refute DynamicExit.open?("xiakedao:yadi", "west")
      refute applied(conn).meta.temp["yadi_swim"]
    end

    test "neili > 150 → 开 west→xiakedao:shidong9、扣 150、5s 定时器" do
      conn =
        XiakedaoYadi.run(conn("xiakedao:yadi", neili: 300, temp: %{"yadi_swim" => true}),
          params("xiakedao:yadi", "men")
        )

      assert DynamicExit.open?("xiakedao:yadi", "west")
      assert exit_target("xiakedao:yadi", "west") == "xiakedao:shidong9"
      assert neili_of(conn) == 150
      refute applied(conn).meta.temp["yadi_swim"]
      assert {:once, _ref} = Room.get_state_by_id("xiakedao:yadi", "exit_timer:push")
    end
  end

  # ---- changan:qunyuys8（bed/床/大床，query_str>=30 开床下暗格，5s 关）----

  describe "changan:qunyuys8" do
    test "空参数 → :not_handled" do
      assert ChanganQunyuys8.run(conn("changan:qunyuys8"), params("changan:qunyuys8", "")) ==
               :not_handled
    end

    test "错词 → :not_handled" do
      assert ChanganQunyuys8.run(conn("changan:qunyuys8"), params("changan:qunyuys8", "table")) ==
               :not_handled
    end

    test "臂力不足 → 提示「没有推开」，不开门" do
      conn =
        ChanganQunyuys8.run(conn("changan:qunyuys8", str: 20), params("changan:qunyuys8", "bed"))

      assert output_text(conn) =~ "没有推开"
      refute DynamicExit.open?("changan:qunyuys8", "enter")
    end

    test "臂力达标 → 开 enter→changan:qunyums、5s 定时器" do
      ChanganQunyuys8.run(conn("changan:qunyuys8", str: 30), params("changan:qunyuys8", "床"))

      assert DynamicExit.open?("changan:qunyuys8", "enter")
      assert exit_target("changan:qunyuys8", "enter") == "changan:qunyums"
      assert {:once, _ref} = Room.get_state_by_id("changan:qunyuys8", "exit_timer:push")
    end

    test "已开 → 只提示暗格、不重复登记定时器" do
      ChanganQunyuys8.run(conn("changan:qunyuys8", str: 30), params("changan:qunyuys8", "大床"))
      DynamicExit.cancel_close("changan:qunyuys8", "exit_timer:push")
      ChanganQunyuys8.run(conn("changan:qunyuys8", str: 30), params("changan:qunyuys8", "大床"))
      refute Room.get_state_by_id("changan:qunyuys8", "exit_timer:push")
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, trailing \\ ""),
    do: %{verb: "push", trailing: trailing, room_id: room_id}

  defp player(room_id, opts) do
    neili = Keyword.get(opts, :neili, 200)
    max_neili = Keyword.get(opts, :max_neili, 200)
    str = Keyword.get(opts, :str, 20)
    unarmed = Keyword.get(opts, :unarmed, 60)
    temp = Keyword.get(opts, :temp, %{})

    vitals = %{Vitals.new() | neili: neili, max_neili: max_neili}
    stats = %{Stats.new() | str: str, skills: Map.put(Stats.new().skills, "unarmed", unarmed)}

    %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new(),
        damage: %{},
        temp: temp,
        env: %{}
      },
      inventory: []
    }
  end

  defp conn(room_id, opts \\ []), do: char_conn(player(room_id, opts))

  defp char_conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp applied(conn), do: conn.private.update_character || conn.character

  defp neili_of(conn), do: applied(conn).meta.vitals.neili

  defp exit_target(room_id, dir) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        pid
        |> :sys.get_state()
        |> Map.get(:data)
        |> Map.get(:exits)
        |> List.wrap()
        |> Enum.find_value(fn exit ->
          if Map.get(exit, :exit_name) == dir, do: Map.get(exit, :end_room_id)
        end)

      _ ->
        nil
    end
  end

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %{data: data} when is_binary(data) -> data
      %Conn.Text{data: data} -> data
      other -> inspect(other)
    end)
    |> Enum.join()
  end

  defp subscribe_room(room_id) do
    channel = "rooms:#{room_id}"

    case Kantele.Communication.register(channel, Kantele.RoomChannel, room_id: room_id) do
      :ok -> :ok
      {:error, :already_registered} -> :ok
    end

    :ok =
      Kantele.Communication.subscribe(channel,
        character: %Kalevala.Character{id: "test-subscriber", room_id: room_id}
      )
  end

  defp flush_room_messages do
    receive do
      {:room_message, _msg} -> flush_room_messages()
    after
      0 -> :ok
    end
  end
end

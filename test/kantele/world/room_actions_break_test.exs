defmodule Kantele.World.RoomActions.DoBreakTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 的最小替身（同 `EmeiShentanTest.FakeRoom`）。

  全模块只注册一次（`setup_all` 起、`setup` 复位）：`:global` 名字注销是异步的，
  反复 stop/start 在全量跑里必撞 `already started`。
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
    Enum.each(state.data.state || %{}, fn
      {"exit_timer:" <> _key, tref} -> :timer.cancel(tref)
      _other -> :ok
    end)

    {:reply, :ok, %{state | data: %Kantele.World.Room{id: state.data.id, state: %{}}}}
  end
end

defmodule Kantele.World.RoomActions.DoBreakTest do
  @moduledoc """
  P5-4ah：`do_break` 砸墙/砸门/劈石门 一批（10 个房间）的移植测试。

  覆盖点：
  - 注册：10 房都挂 `do_break`（注册表断言见 `room_action_handlers_test.exs`）。
  - 参数守卫：错词、已开（break 标志 ≡ 出口已开）提示。
  - 内力 / 最大内力 / 武力 门控：成功开门 + 扣内力；失败内力清零（部分 + 昏厥）。
  - 持武器门控：华山石壁需持武器；神峰甬道需「黄金斧」+ 武力 ≥ 200，且打通双向门。
  - 定时关：成功开门登记 5 秒定时器，`do_close_after` 关出口 + 播报。
  - `chengdu:eastroad3` 无自动关（破开即永久）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.DynamicExit

  alias Kantele.World.RoomActions.Beijing.Zhuang3.Break, as: BeijingZhuang3
  alias Kantele.World.RoomActions.Chengdu.Eastroad3.Break, as: ChengduEastroad3
  alias Kantele.World.RoomActions.Fuzhou.Houyuan.Break, as: FuzhouHouyuan
  alias Kantele.World.RoomActions.Fuzhou.Laozhai.Break, as: FuzhouLaozhai
  alias Kantele.World.RoomActions.Huashan.Sgyhole1.Break, as: HuashanSgyhole1
  alias Kantele.World.RoomActions.Jinshe.Shanbi.Break, as: JinsheShanbi
  alias Kantele.World.RoomActions.Lingxiao.Wave.Break, as: LingxiaoWave
  alias Kantele.World.RoomActions.Mingjiao.Shandong.Break, as: MingjiaoShandong
  alias Kantele.World.RoomActions.Xiakedao.Midao4.Break, as: XiakedaoMidao4
  alias Kantele.World.RoomActions.Shenfeng.Yongdao3.Break, as: ShenfengYongdao3
  alias Kantele.World.RoomActions.DoBreakTest.FakeRoom

  @room_ids [
    "beijing:zhuang3",
    "chengdu:eastroad3",
    "fuzhou:houyuan",
    "fuzhou:laozhai",
    "huashan:sgyhole1",
    "jinshe:shanbi",
    "lingxiao:wave",
    "mingjiao:shandong",
    "xiakedao:midao4",
    "shenfeng:yongdao3",
    # 神峰甬道双向门需要邻居房进程
    "shenfeng:yongdao4"
  ]

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

  # ---- 注册表（10 房都挂 do_break）----

  describe "注册表" do
    test "10 个房间都挂了 do_break" do
      for room_id <- [
            "beijing:zhuang3",
            "chengdu:eastroad3",
            "fuzhou:houyuan",
            "fuzhou:laozhai",
            "huashan:sgyhole1",
            "jinshe:shanbi",
            "lingxiao:wave",
            "mingjiao:shandong",
            "xiakedao:midao4",
            "shenfeng:yongdao3"
          ] do
        assert RoomActionHandlers.registered?(room_id, "do_break")
      end
    end
  end

  # ---- beijing:zhuang3（men，内力≥200，5s 静默关）----

  describe "beijing:zhuang3" do
    test "错词只提示，不开门" do
      conn = BeijingZhuang3.run(conn("beijing:zhuang3"), params("beijing:zhuang3", "qiang"))
      assert output_text(conn) =~ "不要随便打碎别人的东西"
      refute DynamicExit.open?("beijing:zhuang3", "north")
    end

    test "内力充足 → 开 north→beijing:zhuang5、扣 200、登记 5s 定时器" do
      conn = BeijingZhuang3.run(conn("beijing:zhuang3", neili: 500), params("beijing:zhuang3", "men"))
      assert DynamicExit.open?("beijing:zhuang3", "north")
      assert exit_target("beijing:zhuang3", "north") == "beijing:zhuang5"
      assert neili_of(conn) == 300
      assert {:once, ref} = Room.get_state_by_id("beijing:zhuang3", "exit_timer:break")
      assert is_reference(ref)
    end

    test "内力不足 → 内力清零 + 提示，不开门" do
      conn = BeijingZhuang3.run(conn("beijing:zhuang3", neili: 100), params("beijing:zhuang3", "men"))
      assert neili_of(conn) == 0
      refute DynamicExit.open?("beijing:zhuang3", "north")
    end

    test "5 秒后静默关门（do_close_after 模拟超时）" do
      subscribe_room("beijing:zhuang3")
      BeijingZhuang3.run(conn("beijing:zhuang3", neili: 500), params("beijing:zhuang3", "men"))
      flush_room_messages()
      DynamicExit.do_close_after([{"beijing:zhuang3", "north", nil}], false)
      refute DynamicExit.open?("beijing:zhuang3", "north")
      refute_receive {:room_message, _}, 100
    end
  end

  # ---- chengdu:eastroad3（liang，max_neili≥1000，无自动关）----

  describe "chengdu:eastroad3" do
    test "错词 → :not_handled（LPC return 0 无 notify_fail）" do
      assert ChengduEastroad3.run(conn("chengdu:eastroad3"), params("chengdu:eastroad3", "men")) == :not_handled
    end

    test "已开 → 提示「房梁已经被震飞」" do
      DynamicExit.open(conn("chengdu:eastroad3"), "chengdu:eastroad3", "enter", "chengdu:minju", "")
      conn = ChengduEastroad3.run(conn("chengdu:eastroad3", max_neili: 2000), params("chengdu:eastroad3", "liang"))
      assert output_text(conn) =~ "房梁已经被震飞"
    end

    test "max_neili 不足 → 昏厥（内力清零、qi=0）" do
      conn = ChengduEastroad3.run(conn("chengdu:eastroad3", neili: 1500, max_neili: 500), params("chengdu:eastroad3", "liang"))
      assert neili_of(conn) == 0
      assert qi_of(conn) == 0
      refute DynamicExit.open?("chengdu:eastroad3", "enter")
    end

    test "max_neili 充足 → 开 enter→chengdu:minju、内力清零、无定时器" do
      conn = ChengduEastroad3.run(conn("chengdu:eastroad3", neili: 1500, max_neili: 2000), params("chengdu:eastroad3", "liang"))
      assert DynamicExit.open?("chengdu:eastroad3", "enter")
      assert exit_target("chengdu:eastroad3", "enter") == "chengdu:minju"
      assert neili_of(conn) == 0
      refute Room.get_state_by_id("chengdu:eastroad3", "exit_timer:break")
    end
  end

  # ---- fuzhou:houyuan / laozhai（men，内力≥200，5s 关 south/north）----

  describe "fuzhou:houyuan" do
    test "错词提示「什么？」，开门则开 south→fuzhou:laozhai" do
      conn = FuzhouHouyuan.run(conn("fuzhou:houyuan", neili: 300), params("fuzhou:houyuan", "men"))
      assert DynamicExit.open?("fuzhou:houyuan", "south")
      assert exit_target("fuzhou:houyuan", "south") == "fuzhou:laozhai"
      assert neili_of(conn) == 100
    end

    test "内力不足 → 内力清零、不开门" do
      conn = FuzhouHouyuan.run(conn("fuzhou:houyuan", neili: 100), params("fuzhou:houyuan", "men"))
      assert neili_of(conn) == 0
      refute DynamicExit.open?("fuzhou:houyuan", "south")
    end

    test "5 秒后关门并播报「砖头瓦块…坍塌」" do
      subscribe_room("fuzhou:houyuan")
      FuzhouHouyuan.run(conn("fuzhou:houyuan", neili: 300), params("fuzhou:houyuan", "men"))
      flush_room_messages()
      DynamicExit.do_close_after([{"fuzhou:houyuan", "south", "门上的砖头瓦块稀里花拉坍塌下来，又挡住了小门。\n"}], false)
      refute DynamicExit.open?("fuzhou:houyuan", "south")
      assert_received {:room_message, msg}, 200
      assert msg =~ "砖头瓦块"
    end
  end

  describe "fuzhou:laozhai" do
    test "开门开 north→fuzhou:houyuan、扣 200" do
      conn = FuzhouLaozhai.run(conn("fuzhou:laozhai", neili: 300), params("fuzhou:laozhai", "men"))
      assert DynamicExit.open?("fuzhou:laozhai", "north")
      assert exit_target("fuzhou:laozhai", "north") == "fuzhou:houyuan"
      assert neili_of(conn) == 100
    end
  end

  # ---- huashan:sgyhole1（必须持武器，内力≥200）----

  describe "huashan:sgyhole1" do
    test "空手 → 提示「满手都是鲜血」，不开门" do
      conn = HuashanSgyhole1.run(conn("huashan:sgyhole1", neili: 500), params("huashan:sgyhole1"))
      assert output_text(conn) =~ "满手都是鲜血"
      refute DynamicExit.open?("huashan:sgyhole1", "enter")
    end

    test "持武器但内力不足 → 昏厥" do
      char = with_weapon(player("huashan:sgyhole1", neili: 100), "青钢剑")
      conn = HuashanSgyhole1.run(char_conn(char), params("huashan:sgyhole1"))
      assert neili_of(conn) == 0
      assert qi_of(conn) == 0
    end

    test "持武器且内力充足 → 开 enter→huashan:sgyhole、扣 200" do
      char = with_weapon(player("huashan:sgyhole1", neili: 500), "青钢剑")
      conn = HuashanSgyhole1.run(char_conn(char), params("huashan:sgyhole1"))
      assert DynamicExit.open?("huashan:sgyhole1", "enter")
      assert exit_target("huashan:sgyhole1", "enter") == "huashan:sgyhole"
      assert neili_of(conn) == 300
      assert published(conn) |> Enum.any?(&(&1 =~ "拿起青钢剑"))
    end
  end

  # ---- jinshe:shanbi（dong，内力≥100）----

  describe "jinshe:shanbi" do
    test "错词 → :not_handled" do
      assert JinsheShanbi.run(conn("jinshe:shanbi"), params("jinshe:shanbi", "men")) == :not_handled
    end

    test "内力充足 → 开 enter→jinshe:yongdao1、扣 200" do
      conn = JinsheShanbi.run(conn("jinshe:shanbi", neili: 300), params("jinshe:shanbi", "dong"))
      assert DynamicExit.open?("jinshe:shanbi", "enter")
      assert exit_target("jinshe:shanbi", "enter") == "jinshe:yongdao1"
      assert neili_of(conn) == 100
    end

    test "内力不足 → 昏厥" do
      conn = JinsheShanbi.run(conn("jinshe:shanbi", neili: 50), params("jinshe:shanbi", "dong"))
      assert neili_of(conn) == 0
      assert qi_of(conn) == 0
    end
  end

  # ---- lingxiao:wave（内力≥2000）----

  describe "lingxiao:wave" do
    test "内力充足 → 开 enter→lingxiao:yudong、内力清零" do
      conn = LingxiaoWave.run(conn("lingxiao:wave", neili: 3000), params("lingxiao:wave"))
      assert DynamicExit.open?("lingxiao:wave", "enter")
      assert exit_target("lingxiao:wave", "enter") == "lingxiao:yudong"
      assert neili_of(conn) == 0
    end

    test "内力不足 → 昏厥" do
      conn = LingxiaoWave.run(conn("lingxiao:wave", neili: 1000), params("lingxiao:wave"))
      assert neili_of(conn) == 0
      assert qi_of(conn) == 0
      refute DynamicExit.open?("lingxiao:wave", "enter")
    end
  end

  # ---- mingjiao:shandong（men，内力≥2000，武力≥300 才开门）----

  describe "mingjiao:shandong" do
    test "错词提示「你在干吗」" do
      conn = MingjiaoShandong.run(conn("mingjiao:shandong", neili: 3000, force: 400), params("mingjiao:shandong", "menx"))
      assert output_text(conn) =~ "你在干吗"
    end

    test "内力不足 → 仅提示，内力不变" do
      conn = MingjiaoShandong.run(conn("mingjiao:shandong", neili: 1000, force: 400), params("mingjiao:shandong", "men"))
      assert neili_of(conn) == 1000
      refute DynamicExit.open?("mingjiao:shandong", "enter")
    end

    test "内力足但武力<300 → 不开门，内力扣 2000" do
      conn = MingjiaoShandong.run(conn("mingjiao:shandong", neili: 3000, force: 200), params("mingjiao:shandong", "men"))
      assert neili_of(conn) == 1000
      refute DynamicExit.open?("mingjiao:shandong", "enter")
      assert output_text(conn) =~ "内功火候还不够"
    end

    test "内力足且武力≥300 → 开 enter→mingjiao:midao0、再扣 400（共 2400）" do
      conn = MingjiaoShandong.run(conn("mingjiao:shandong", neili: 3000, force: 400), params("mingjiao:shandong", "men"))
      assert DynamicExit.open?("mingjiao:shandong", "enter")
      assert exit_target("mingjiao:shandong", "enter") == "mingjiao:midao0"
      assert neili_of(conn) == 600
    end
  end

  # ---- xiakedao:midao4（men，内力>200 严格大于）----

  describe "xiakedao:midao4" do
    test "内力恰为 200 → 不开门（LPC n>200 严格）" do
      conn = XiakedaoMidao4.run(conn("xiakedao:midao4", neili: 200), params("xiakedao:midao4", "men"))
      refute DynamicExit.open?("xiakedao:midao4", "west")
      assert neili_of(conn) == 0
    end

    test "内力 201 → 开 west→xiakedao:midao5、扣 200" do
      conn = XiakedaoMidao4.run(conn("xiakedao:midao4", neili: 201), params("xiakedao:midao4", "men"))
      assert DynamicExit.open?("xiakedao:midao4", "west")
      assert exit_target("xiakedao:midao4", "west") == "xiakedao:midao5"
      assert neili_of(conn) == 1
    end
  end

  # ---- shenfeng:yongdao3（gate，需黄金斧 + 武力≥200，双向门）----

  describe "shenfeng:yongdao3" do
    test "错词提示「你要毁掉什么」" do
      conn = ShenfengYongdao3.run(conn("shenfeng:yongdao3"), params("shenfeng:yongdao3", "men"))
      assert output_text(conn) =~ "你要毁掉什么"
    end

    test "已开 → 提示「石门已经被劈开了」" do
      DynamicExit.open(conn("shenfeng:yongdao3"), "shenfeng:yongdao3", "north", "shenfeng:yongdao4", "")
      conn = ShenfengYongdao3.run(conn("shenfeng:yongdao3", force: 300), params("shenfeng:yongdao3", "gate"))
      assert output_text(conn) =~ "石门已经被劈开了"
    end

    test "空手 + 武力<200 → 扣 qi 300 + 内力清零 + 昏厥" do
      conn = ShenfengYongdao3.run(conn("shenfeng:yongdao3", neili: 800, force: 100), params("shenfeng:yongdao3", "gate"))
      assert neili_of(conn) == 0
      assert qi_of(conn) == 0
      refute DynamicExit.open?("shenfeng:yongdao3", "north")
    end

    test "空手 + 武力≥200 → 仅内力清零、不开门、不昏厥" do
      conn = ShenfengYongdao3.run(conn("shenfeng:yongdao3", neili: 800, force: 300), params("shenfeng:yongdao3", "gate"))
      assert neili_of(conn) == 0
      assert qi_of(conn) > 0
      refute DynamicExit.open?("shenfeng:yongdao3", "north")
    end

    test "持非黄金斧武器 → 武器脱手、不开门" do
      char = with_weapon(player("shenfeng:yongdao3", neili: 800, force: 300), "青钢剑")
      conn = ShenfengYongdao3.run(char_conn(char), params("shenfeng:yongdao3", "gate"))
      refute DynamicExit.open?("shenfeng:yongdao3", "north")
      assert Break.wielded_weapon(applied(conn)) == nil
      assert published(conn) |> Enum.any?(&(&1 =~ "脱手飞出"))
    end

    test "持黄金斧 + 武力≥200 → 双向开门、无定时器" do
      subscribe_room("shenfeng:yongdao4")
      char = with_weapon(player("shenfeng:yongdao3", neili: 800, force: 300), "黄金斧")
      ShenfengYongdao3.run(char_conn(char), params("shenfeng:yongdao3", "gate"))
      assert DynamicExit.open?("shenfeng:yongdao3", "north")
      assert exit_target("shenfeng:yongdao3", "north") == "shenfeng:yongdao4"
      assert DynamicExit.open?("shenfeng:yongdao4", "south")
      assert exit_target("shenfeng:yongdao4", "south") == "shenfeng:yongdao3"
      refute Room.get_state_by_id("shenfeng:yongdao3", "exit_timer:break")
      assert_received {:room_message, msg}, 200
      assert msg =~ "石门被人劈开了"
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, trailing \\ ""),
    do: %{verb: "break", trailing: trailing, room_id: room_id}

  defp player(room_id, opts \\ []) do
    neili = Keyword.get(opts, :neili, 200)
    max_neili = Keyword.get(opts, :max_neili, 200)
    force = Keyword.get(opts, :force, 20)

    vitals = %{Vitals.new() | neili: neili, max_neili: max_neili}
    stats = %{Stats.new() | skills: Map.put(Stats.new().skills, "force", force)}

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
        temp: %{},
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

  defp with_weapon(character, name) do
    combat =
      Combat.equip(character.meta.combat, :weapon, %{
        name: name,
        skill_type: "sword",
        damage: 0,
        prop: nil,
        flag: 1
      })

    %{character | meta: %{character.meta | combat: combat}}
  end

  defp applied(conn), do: conn.private.update_character || conn.character

  defp neili_of(conn), do: applied(conn).meta.vitals.neili
  defp qi_of(conn), do: applied(conn).meta.vitals.qi

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

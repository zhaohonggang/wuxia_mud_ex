defmodule Kantele.World.RoomActions.MoveStoneTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `TriggerTest.FakeRoom`）。
  全模块只注册一次（`setup_all` 起、`setup` 复位）。额外提供 `set_characters/2`
  模拟房内 NPC 在场（开封花园小筑的余鱼同准入检查用）。
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

  def set_characters(room_id, chars) when is_list(chars) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) -> GenServer.call(pid, {:set_characters, chars})
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

  @impl true
  def handle_call({:set_characters, chars}, _from, state) do
    {:reply, :ok, %{state | private: %{state.private | characters: chars}}}
  end
end

defmodule Kantele.World.RoomActions.MoveStoneTest do
  @moduledoc """
  P5-4an：「移像/推石/推桌」型 `do_*` 一批（10 房 `do_move` + 1 房 `do_push`）的移植测试。

  共用 `RoomActions.MoveStone` 共享原语：参数校验 → 属性门控（臂力/内力/最大内力/
  基本内功/基本拳/门派/NPC 在场/玩家与房间临时标记）→ 开出口（多数定时自关）。

  延后未移植：`shenfeng:shenfeng` 的 `do_push`（失败分支 `me->move` +
  `receive_wound` + `unconcious`，需引擎位移/受伤/昏厥支持）。
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
  alias Kantele.World.RoomActions.Emei.Hcadadian.Move, as: HcadadianMove
  alias Kantele.World.RoomActions.Gumu.Mumen.Move, as: MumenMove
  alias Kantele.World.RoomActions.Hengyang.Outzigai1.Push, as: Outzigai1Push
  alias Kantele.World.RoomActions.Jingzhou.Luan2.Move, as: Luan2Move
  alias Kantele.World.RoomActions.Jinshe.Yongdao2.Move, as: Yongdao2Move
  alias Kantele.World.RoomActions.Kaifeng.HhXiaozhu.Move, as: HhXiaozhuMove
  alias Kantele.World.RoomActions.MoveStone
  alias Kantele.World.RoomActions.MoveStoneTest.FakeRoom
  alias Kantele.World.RoomActions.Shaolin.Beilin2.Move, as: Beilin2Move
  alias Kantele.World.RoomActions.Shenfeng.Yushi.Move, as: YushiMove
  alias Kantele.World.RoomActions.Tiezhang.Wmfeng.Move, as: WmfengMove
  alias Kantele.World.RoomActions.Wudang.Nanyangong.Move, as: NanyangongMove
  alias Kantele.World.RoomActions.Wudu.Huating2.Move, as: Huating2Move

  @room_ids [
    "emei:hcadadian",
    "gumu:mumen",
    "jingzhou:luan2",
    "tiezhang:wmfeng",
    "jinshe:yongdao2",
    "kaifeng:hh_xiaozhu",
    "shaolin:beilin2",
    "shenfeng:yushi",
    "shenfeng:yongdao5",
    "wudang:nanyangong",
    "wudang:nanyan0",
    "wudu:huating2",
    "hengyang:outzigai1",
    "hengyang:zigaihole"
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

  # ---- 注册表 ---------------------------------------------------------------

  describe "注册表" do
    test "十一房都已注册" do
      assert RoomActionHandlers.lookup("emei:hcadadian", "do_move") == {:ok, {HcadadianMove, :run}}
      assert RoomActionHandlers.lookup("gumu:mumen", "do_move") == {:ok, {MumenMove, :run}}
      assert RoomActionHandlers.lookup("jingzhou:luan2", "do_move") == {:ok, {Luan2Move, :run}}
      assert RoomActionHandlers.lookup("tiezhang:wmfeng", "do_move") == {:ok, {WmfengMove, :run}}
      assert RoomActionHandlers.lookup("jinshe:yongdao2", "do_move") == {:ok, {Yongdao2Move, :run}}

      assert RoomActionHandlers.lookup("kaifeng:hh_xiaozhu", "do_move") ==
               {:ok, {HhXiaozhuMove, :run}}

      assert RoomActionHandlers.lookup("shaolin:beilin2", "do_move") == {:ok, {Beilin2Move, :run}}
      assert RoomActionHandlers.lookup("shenfeng:yushi", "do_move") == {:ok, {YushiMove, :run}}

      assert RoomActionHandlers.lookup("wudang:nanyangong", "do_move") ==
               {:ok, {NanyangongMove, :run}}

      assert RoomActionHandlers.lookup("wudu:huating2", "do_move") == {:ok, {Huating2Move, :run}}
      assert RoomActionHandlers.lookup("hengyang:outzigai1", "do_push") == {:ok, {Outzigai1Push, :run}}
    end
  end

  # ---- emei:hcadadian（移普贤菩萨像） ----

  describe "emei:hcadadian（move xiang 移菩萨像）" do
    test "错词 → 你要移动什么" do
      conn = HcadadianMove.run(conn("emei:hcadadian"), params("emei:hcadadian", "desk"))
      assert output(conn) == ["你要移动什么？\n"]
      refute DynamicExit.open?("emei:hcadadian", "down")
    end

    test "已开 → 座像已经被移开了" do
      HcadadianMove.run(conn("emei:hcadadian"), params("emei:hcadadian", "xiang"))
      conn = HcadadianMove.run(conn("emei:hcadadian"), params("emei:hcadadian", "xiang"))
      assert output(conn) == ["座像已经被移开了。\n"]
    end

    test "move xiang → 开 down→midao + 8s 定时器 + 广播" do
      conn = HcadadianMove.run(conn("emei:hcadadian"), params("emei:hcadadian", "xiang"))

      assert DynamicExit.open?("emei:hcadadian", "down")
      assert exit_target("emei:hcadadian", "down") == "emei:midao"
      assert published(conn) ==
               ["\n{npc}刚一推动普贤菩萨像，那座像却自己向一方移开，地面现出一个洞口。\n\n"]
      assert {:once, _ref} =
               Room.get_state_by_id("emei:hcadadian", "exit_timer:movestone:emei:hcadadian")
    end

    test "8 秒后坐像缩回自关" do
      HcadadianMove.run(conn("emei:hcadadian"), params("emei:hcadadian", "xiang"))

      :ok =
        DynamicExit.do_close_after(
          [{"emei:hcadadian", "down", "忽然只听「喀喀喀」几声，普贤菩萨像缩回原地，把密道挡住了。\n"}],
          false
        )

      refute DynamicExit.open?("emei:hcadadian", "down")
    end
  end

  # ---- gumu:mumen（推巨石） ----

  describe "gumu:mumen（move shi 推巨石）" do
    test "错词 → 你要移动什么" do
      conn = MumenMove.run(conn("gumu:mumen"), params("gumu:mumen", "bi"))
      assert output(conn) == ["你要移动什么？\n"]
      refute DynamicExit.open?("gumu:mumen", "south")
    end

    test "move shi → 开 south→qianting + 5s 定时器" do
      conn = MumenMove.run(conn("gumu:mumen"), params("gumu:mumen", "shi"))

      assert DynamicExit.open?("gumu:mumen", "south")
      assert exit_target("gumu:mumen", "south") == "gumu:qianting"
      assert published(conn) |> Enum.any?(&(&1 =~ "现出一道门户来"))
      assert {:once, _ref} =
               Room.get_state_by_id("gumu:mumen", "exit_timer:movestone:gumu:mumen")
    end
  end

  # ---- wudu:huating2（移香炉） ----

  describe "wudu:huating2（move lu 移香炉）" do
    test "错词 → 你要移动什么" do
      conn = Huating2Move.run(conn("wudu:huating2"), params("wudu:huating2", "ding"))
      assert output(conn) == ["你要移动什么？\n"]
      refute DynamicExit.open?("wudu:huating2", "down")
    end

    test "已开 → 香炉已经被移开了" do
      Huating2Move.run(conn("wudu:huating2"), params("wudu:huating2", "lu"))
      conn = Huating2Move.run(conn("wudu:huating2"), params("wudu:huating2", "lu"))
      assert output(conn) == ["香炉已经被移开了。\n"]
    end

    test "move lu → 开 down→midao + 8s 定时器" do
      conn = Huating2Move.run(conn("wudu:huating2"), params("wudu:huating2", "lu"))

      assert DynamicExit.open?("wudu:huating2", "down")
      assert exit_target("wudu:huating2", "down") == "wudu:midao"
      assert published(conn) |> Enum.any?(&(&1 =~ "地面豁然现出一个洞口"))
      assert {:once, _ref} =
               Room.get_state_by_id("wudu:huating2", "exit_timer:movestone:wudu:huating2")
    end
  end

  # ---- jinshe:yongdao2（推巨石开山洞，内力+臂力门控） ----

  describe "jinshe:yongdao2（move stone 推巨石）" do
    test "错词 → 你要移动什么" do
      conn = Yongdao2Move.run(conn("jinshe:yongdao2"), params("jinshe:yongdao2", "shi"))
      assert output(conn) == ["你要移动什么？\n"]
      refute DynamicExit.open?("jinshe:yongdao2", "north")
    end

    test "内力不足 → 吃奶的劲也没能移动 + 内力清零" do
      conn =
        Yongdao2Move.run(
          conn("jinshe:yongdao2", neili: 100, str: 40),
          params("jinshe:yongdao2", "stone")
        )

      assert published(conn) == ["{npc}使出吃奶的劲也没能移动巨石。\n"]
      assert neili_of(conn) == 0
      refute DynamicExit.open?("jinshe:yongdao2", "north")
    end

    test "臂力不足 → 同上（内力够也不开）" do
      conn =
        Yongdao2Move.run(
          conn("jinshe:yongdao2", neili: 2000, str: 20),
          params("jinshe:yongdao2", "stone")
        )

      assert published(conn) == ["{npc}使出吃奶的劲也没能移动巨石。\n"]
      assert neili_of(conn) == 0
      refute DynamicExit.open?("jinshe:yongdao2", "north")
    end

    test "move stone（内力+臂力达标）→ 开 north→shandong + 扣 1000 + 5s 定时器" do
      conn =
        Yongdao2Move.run(
          conn("jinshe:yongdao2", neili: 2000, str: 40),
          params("jinshe:yongdao2", "stone")
        )

      assert DynamicExit.open?("jinshe:yongdao2", "north")
      assert exit_target("jinshe:yongdao2", "north") == "jinshe:shandong"
      assert published(conn) |> Enum.any?(&(&1 =~ "现出一个山洞来"))
      assert neili_of(conn) == 1000
      assert {:once, _ref} =
               Room.get_state_by_id("jinshe:yongdao2", "exit_timer:movestone:jinshe:yongdao2")
    end
  end

  # ---- jingzhou:luan2 / tiezhang:wmfeng（推墓碑，臂力+内功门控） ----

  describe "jingzhou:luan2（move bei 推墓碑）" do
    test "错词 → 你要推什么" do
      conn = Luan2Move.run(conn("jingzhou:luan2"), params("jingzhou:luan2", "shi"))
      assert output(conn) == ["你要推什么？\n"]
      refute DynamicExit.open?("jingzhou:luan2", "enter")
    end

    test "臂力不足 → 吃奶的劲都用上了" do
      conn =
        Luan2Move.run(
          conn("jingzhou:luan2", str: 20, force: 100),
          params("jingzhou:luan2", "bei")
        )

      assert output(conn) == ["你将吃奶的劲都用上了，可还是无法把石碑推开。\n"]
      refute DynamicExit.open?("jingzhou:luan2", "enter")
    end

    test "基本内功不足 → 推了半天还是纹丝不动" do
      conn =
        Luan2Move.run(
          conn("jingzhou:luan2", str: 40, force: 50),
          params("jingzhou:luan2", "bei")
        )

      assert output(conn) == ["你推了半天，发现石碑还是纹丝不动。\n"]
      refute DynamicExit.open?("jingzhou:luan2", "enter")
    end

    test "move bei → 本人 write + 房间广播（排除行动者）+ 开 enter→tomb + 10s 定时器" do
      subscribe_room("jingzhou:luan2")

      conn =
        Luan2Move.run(
          conn("jingzhou:luan2", str: 40, force: 100, name: "令狐冲"),
          params("jingzhou:luan2", "bei")
        )

      # 本人只看到 write 的那句
      assert output(conn) == ["你扎下马步，深深的吸了口气，将墓碑缓缓的向旁推开，下面露出一个黑洞洞的入口。\n"]
      # 旁观者看到带名字的广播（不含 $N 占位）
      assert published(conn) == ["令狐冲双膀用力，将墓碑向旁缓缓推开，下面露出一个黑洞洞的入口。\n"]

      assert DynamicExit.open?("jingzhou:luan2", "enter")
      assert exit_target("jingzhou:luan2", "enter") == "jingzhou:tomb"
      assert {:once, _ref} =
               Room.get_state_by_id("jingzhou:luan2", "exit_timer:movestone:jingzhou:luan2")
    end

    test "10 秒后墓碑合回自关" do
      Luan2Move.run(conn("jingzhou:luan2", str: 40, force: 100), params("jingzhou:luan2", "bei"))

      :ok =
        DynamicExit.do_close_after(
          [{"jingzhou:luan2", "enter", "墓碑发出隆隆的声音，缓缓移回原处。\n"}],
          false
        )

      refute DynamicExit.open?("jingzhou:luan2", "enter")
    end
  end

  describe "tiezhang:wmfeng（move bei 推墓碑，铁掌帮）" do
    test "错词 → 你要推什么" do
      conn = WmfengMove.run(conn("tiezhang:wmfeng"), params("tiezhang:wmfeng", "shi"))
      assert output(conn) == ["你要推什么？\n"]
    end

    test "臂力不足 → 吃奶的劲都用上了" do
      conn = WmfengMove.run(conn("tiezhang:wmfeng", str: 20, force: 100), params("tiezhang:wmfeng", "bei"))
      assert output(conn) == ["你将吃奶的劲都用上了，可还是无法把石碑推开。\n"]
    end

    test "move bei → 开 enter→shijie_1 + 10s 定时器（文件名 shijie-1 规范化为 shijie_1）" do
      conn = WmfengMove.run(conn("tiezhang:wmfeng", str: 40, force: 100), params("tiezhang:wmfeng", "bei"))

      assert DynamicExit.open?("tiezhang:wmfeng", "enter")
      assert exit_target("tiezhang:wmfeng", "enter") == "tiezhang:shijie_1"
      assert output(conn) == ["你扎下马步，深深的吸了口气，将墓碑缓缓的向旁推开，下面露出一个黑洞洞的入口。\n"]
      assert {:once, _ref} =
               Room.get_state_by_id("tiezhang:wmfeng", "exit_timer:movestone:tiezhang:wmfeng")
    end
  end

  # ---- kaifeng:hh_xiaozhu（推石桌，门派 + NPC 在场 + 最大内力门控） ----

  describe "kaifeng:hh_xiaozhu（move zhuo 推石桌）" do
    test "错词 → :not_handled（放行全局）" do
      assert HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu"), params("kaifeng:hh_xiaozhu", "yi")) ==
               :not_handled
    end

    test "已开 → 石桌已经被移开了" do
      HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu", max_neili: 1000), params("kaifeng:hh_xiaozhu", "zhuo"))
      conn = HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu", max_neili: 1000), params("kaifeng:hh_xiaozhu", "zhuo"))
      assert output(conn) == ["石桌已经被移开了，你还移它作甚？\n"]
    end

    test "非红花会 + 余鱼同在场 → 被喝退" do
      FakeRoom.set_characters("kaifeng:hh_xiaozhu", [%Kalevala.Character{id: "clone_lib:honghua_yu", name: "余鱼同"}])

      conn = HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu", max_neili: 1000), params("kaifeng:hh_xiaozhu", "zhuo"))

      assert output(conn) == ["余鱼同眉头一皱，喝道：阁下什么来头，居然敢在这里猖狂？\n"]
      refute DynamicExit.open?("kaifeng:hh_xiaozhu", "down")
    end

    test "非红花会 + 余鱼同不在场 → 放行（NPC 被杀后）" do
      conn = HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu", max_neili: 1000), params("kaifeng:hh_xiaozhu", "zhuo"))
      assert DynamicExit.open?("kaifeng:hh_xiaozhu", "down")
      assert neili_of(conn) == 0
    end

    test "红花会弟子 + 余鱼同在场 → 放行" do
      FakeRoom.set_characters("kaifeng:hh_xiaozhu", [%Kalevala.Character{id: "clone_lib:honghua_yu", name: "余鱼同"}])

      conn =
        HhXiaozhuMove.run(
          conn("kaifeng:hh_xiaozhu", max_neili: 1000, family: "红花会"),
          params("kaifeng:hh_xiaozhu", "zhuo")
        )

      assert DynamicExit.open?("kaifeng:hh_xiaozhu", "down")
      assert neili_of(conn) == 0
    end

    test "最大内力不足 → 纹丝不动 + 内力清零" do
      conn = HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu", max_neili: 500), params("kaifeng:hh_xiaozhu", "zhuo"))

      assert published(conn) |> Enum.any?(&(&1 =~ "石桌还是纹丝不动"))
      assert neili_of(conn) == 0
      refute DynamicExit.open?("kaifeng:hh_xiaozhu", "down")
    end

    test "move zhuo（达标）→ 开 down→hh_mishi + 10s 定时器 + 成功也清内力" do
      conn = HhXiaozhuMove.run(conn("kaifeng:hh_xiaozhu", max_neili: 1000), params("kaifeng:hh_xiaozhu", "zhuo"))

      assert DynamicExit.open?("kaifeng:hh_xiaozhu", "down")
      assert exit_target("kaifeng:hh_xiaozhu", "down") == "kaifeng:hh_mishi"
      assert published(conn) |> Enum.any?(&(&1 =~ "向下露出一个黑洞洞的入口"))
      assert neili_of(conn) == 0
      assert {:once, _ref} =
               Room.get_state_by_id("kaifeng:hh_xiaozhu", "exit_timer:movestone:kaifeng:hh_xiaozhu")
    end
  end

  # ---- shaolin:beilin2（推佛塔，无定时关） ----

  describe "shaolin:beilin2（move stone 推佛塔）" do
    test "错词 → :not_handled（放行全局 move）" do
      assert Beilin2Move.run(conn("shaolin:beilin2"), params("shaolin:beilin2", "ta")) ==
               :not_handled
    end

    test "已开 → 佛塔已经被移开了" do
      Beilin2Move.run(conn("shaolin:beilin2", max_neili: 1000), params("shaolin:beilin2", "stone"))
      conn = Beilin2Move.run(conn("shaolin:beilin2", max_neili: 1000), params("shaolin:beilin2", "stone"))
      assert output(conn) == ["佛塔已经被移开了，你还移它作甚？\n"]
    end

    test "最大内力不足 → 纹丝不动 + 内力清零" do
      conn = Beilin2Move.run(conn("shaolin:beilin2", max_neili: 500), params("shaolin:beilin2", "stone"))

      assert published(conn) |> Enum.any?(&(&1 =~ "佛塔还是纹丝不动"))
      assert neili_of(conn) == 0
      refute DynamicExit.open?("shaolin:beilin2", "down")
    end

    test "move stone → 开 down→beilin3，无定时器，成功清内力" do
      conn = Beilin2Move.run(conn("shaolin:beilin2", max_neili: 1000), params("shaolin:beilin2", "stone"))

      assert DynamicExit.open?("shaolin:beilin2", "down")
      assert exit_target("shaolin:beilin2", "down") == "shaolin:beilin3"
      assert neili_of(conn) == 0
      refute Room.get_state_by_id("shaolin:beilin2", "exit_timer:movestone:shaolin:beilin2")
    end
  end

  # ---- shenfeng:yushi（拉圆桌，marks/爬1 门槛 + 双向） ----

  describe "shenfeng:yushi（move table 拉圆桌）" do
    test "无 marks/爬1 → 什么？" do
      conn = YushiMove.run(conn("shenfeng:yushi"), params("shenfeng:yushi", "table"))
      assert output(conn) == ["什么？\n"]
      refute DynamicExit.open?("shenfeng:yushi", "enter")
    end

    test "有 marks 但错词 → 你要移动什么？" do
      conn =
        YushiMove.run(
          conn("shenfeng:yushi", temp: %{"marks/爬1" => 1}),
          params("shenfeng:yushi", "zhuo")
        )

      assert output(conn) == ["你要移动什么？\n"]
      refute DynamicExit.open?("shenfeng:yushi", "enter")
    end

    test "move table → 开 enter↔yongdao5 双向 + 消耗 marks/爬1 + 无定时器" do
      conn =
        YushiMove.run(
          conn("shenfeng:yushi", temp: %{"marks/爬1" => 1}),
          params("shenfeng:yushi", "table")
        )

      assert DynamicExit.open?("shenfeng:yushi", "enter")
      assert exit_target("shenfeng:yushi", "enter") == "shenfeng:yongdao5"
      assert DynamicExit.open?("shenfeng:yongdao5", "out")
      assert exit_target("shenfeng:yongdao5", "out") == "shenfeng:yushi"

      assert character_of(conn).meta.temp["marks/爬1"] == nil
      assert published(conn) |> Enum.any?(&(&1 =~ "玉床登时露出一个洞口"))
      refute Room.get_state_by_id("shenfeng:yushi", "exit_timer:movestone:shenfeng:yushi")
    end

    test "已开再 move table → 你要移动什么？（LPC 兜底文案）" do
      YushiMove.run(
        conn("shenfeng:yushi", temp: %{"marks/爬1" => 1}),
        params("shenfeng:yushi", "table")
      )

      conn =
        YushiMove.run(
          conn("shenfeng:yushi", temp: %{"marks/爬1" => 1}),
          params("shenfeng:yushi", "table")
        )

      assert output(conn) == ["你要移动什么？\n"]
      assert DynamicExit.open?("shenfeng:yushi", "enter")
    end
  end

  # ---- wudang:nanyangong（推老君像，双向 + 3s 双侧播报） ----

  describe "wudang:nanyangong（move xiang 推老君像）" do
    test "错词 → 你要移动什么" do
      conn = NanyangongMove.run(conn("wudang:nanyangong"), params("wudang:nanyangong", "ren"))
      assert output(conn) == ["你要移动什么？\n"]
      refute DynamicExit.open?("wudang:nanyangong", "down")
    end

    test "move xiang → 开 down↔nanyan0 双向 + 邻房消息 + 3s 定时器" do
      subscribe_room("wudang:nanyangong")
      subscribe_room("wudang:nanyan0")

      conn = NanyangongMove.run(conn("wudang:nanyangong"), params("wudang:nanyangong", "xiang"))

      assert DynamicExit.open?("wudang:nanyangong", "down")
      assert exit_target("wudang:nanyangong", "down") == "wudang:nanyan0"
      assert DynamicExit.open?("wudang:nanyan0", "up")
      assert exit_target("wudang:nanyan0", "up") == "wudang:nanyangong"

      assert published(conn) |> Enum.any?(&(&1 =~ "几排石阶往下伸去"))

      assert_received {:room_message, msg}, 200
      assert msg =~ "天花板忽然发出轧轧的声音"

      assert {:once, _ref} =
               Room.get_state_by_id("wudang:nanyangong", "exit_timer:movestone:wudang:nanyangong")
    end

    test "3 秒后两侧播报、只删本房 down" do
      NanyangongMove.run(conn("wudang:nanyangong"), params("wudang:nanyangong", "xiang"))

      :ok =
        DynamicExit.do_close_after(
          [
            {"wudang:nanyangong", "down", "\n只听乒地一声响，老君像自动移回原处。\n"},
            {"wudang:nanyan0", "up", "\n只听乒地一声响，向上的洞口自动严严实实地关了起来。\n"}
          ],
          false
        )

      refute DynamicExit.open?("wudang:nanyangong", "down")
    end
  end

  # ---- hengyang:outzigai1（推石壁，房间级 temp + 双向 + 13s） ----

  describe "hengyang:outzigai1（push/tui bi 推石壁）" do
    test "错词 → 你要推什么" do
      conn = Outzigai1Push.run(conn("hengyang:outzigai1", neili: 2000, unarmed: 100), params("hengyang:outzigai1", "qiang"))
      assert output(conn) == ["你要推什么？\n"]
      refute DynamicExit.open?("hengyang:outzigai1", "enter")
    end

    test "内力不足 → 纹丝不动" do
      conn =
        Outzigai1Push.run(
          conn("hengyang:outzigai1", neili: 100, unarmed: 100),
          params("hengyang:outzigai1", "bi")
        )

      assert output(conn) == ["你使出浑身解数用力推石壁，可以石壁却纹丝不动。\n"]
      refute DynamicExit.open?("hengyang:outzigai1", "enter")
    end

    test "基本拳不足 → 纹丝不动" do
      conn =
        Outzigai1Push.run(
          conn("hengyang:outzigai1", neili: 2000, unarmed: 50),
          params("hengyang:outzigai1", "bi")
        )

      assert output(conn) == ["你使出浑身解数用力推石壁，可以石壁却纹丝不动。\n"]
    end

    test "push bi → 双向门 + 两侧房间 temp + 两侧纯文本 + 13s 定时器" do
      subscribe_room("hengyang:outzigai1")
      subscribe_room("hengyang:zigaihole")

      conn =
        Outzigai1Push.run(
          conn("hengyang:outzigai1", neili: 2000, unarmed: 100),
          params("hengyang:outzigai1", "bi")
        )

      assert DynamicExit.open?("hengyang:outzigai1", "enter")
      assert exit_target("hengyang:outzigai1", "enter") == "hengyang:zigaihole"
      assert DynamicExit.open?("hengyang:zigaihole", "out")
      assert exit_target("hengyang:zigaihole", "out") == "hengyang:outzigai1"

      # 房间级 temp 落在房间进程 state（look bi 的 room_temp_tiers 依赖它）
      assert MoveStone.room_temp("hengyang:outzigai1", "marks/推") == 1
      assert MoveStone.room_temp("hengyang:zigaihole", "marks/推") == 1

      assert published(conn) |> Enum.any?(&(&1 =~ "这竟是一扇石门"))

      assert_received {:room_message, self_msg}, 200
      assert self_msg =~ "阳光照射了进来，耀眼夺目。"

      assert_received {:room_message, neighbor_msg}, 200
      assert neighbor_msg =~ "洞外轰！地一声，像是有人将石门推开了。"

      assert {:once, _ref} =
               Room.get_state_by_id("hengyang:outzigai1", "exit_timer:movestone:hengyang:outzigai1")
    end

    test "房间 temp 已置 → 石门已经被推开了（幂等守卫）" do
      MoveStone.put_room_temp("hengyang:outzigai1", "marks/推", 1)

      conn =
        Outzigai1Push.run(
          conn("hengyang:outzigai1", neili: 2000, unarmed: 100),
          params("hengyang:outzigai1", "bi")
        )

      assert output(conn) == ["石门已经被推开了。\n"]
      refute DynamicExit.open?("hengyang:outzigai1", "enter")
    end

    test "13 秒后 auto_close：两侧出口与两侧房间 temp 一起回收" do
      Outzigai1Push.run(
        conn("hengyang:outzigai1", neili: 2000, unarmed: 100),
        params("hengyang:outzigai1", "bi")
      )

      :ok =
        DynamicExit.do_close_after(
          [
            {"hengyang:outzigai1", "enter", "\n轰！轰！轰！不知道谁将石门关上了，顿时山洞里变得阴暗起来。\n"},
            {"hengyang:zigaihole", "out", "\n轰！轰！轰！不知道谁将石门关上了。\n"}
          ],
          false
        )

      :ok =
        MoveStone.clear_room_temps([
          {"hengyang:outzigai1", "marks/推"},
          {"hengyang:zigaihole", "marks/推"}
        ])

      refute DynamicExit.open?("hengyang:outzigai1", "enter")
      refute DynamicExit.open?("hengyang:zigaihole", "out")
      assert MoveStone.room_temp("hengyang:outzigai1", "marks/推") == nil
      assert MoveStone.room_temp("hengyang:zigaihole", "marks/推") == nil
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, arg, verb \\ "move") do
    %{verb: verb, trailing: arg, room_id: room_id}
  end

  defp conn(room_id, opts \\ []) do
    neili = Keyword.get(opts, :neili, 200)
    max_neili = Keyword.get(opts, :max_neili, 200)
    str = Keyword.get(opts, :str, 20)
    force = Keyword.get(opts, :force, 20)
    unarmed = Keyword.get(opts, :unarmed, 60)
    temp = Keyword.get(opts, :temp, %{})
    family = Keyword.get(opts, :family)
    inventory = Keyword.get(opts, :inventory, [])

    vitals = %{Vitals.new() | neili: neili, max_neili: max_neili}
    skills = Stats.new().skills |> Map.put("force", force) |> Map.put("unarmed", unarmed)
    stats = %{Stats.new() | str: str, skills: skills}

    meta = %PlayerMeta{
      vitals: vitals,
      stats: stats,
      combat: Combat.new(),
      damage: %{},
      temp: temp,
      env: %{}
    }

    meta = if family, do: %{meta | family: %{name: family}}, else: meta

    character = %Kalevala.Character{
      id: "test-player",
      name: Keyword.get(opts, :name, "玩家"),
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: meta,
      inventory: inventory
    }

    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  defp neili_of(conn), do: character_of(conn).meta.vitals.neili

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

  defp output(conn), do: Enum.map(conn.output, & &1.data)

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
end

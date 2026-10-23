defmodule Kantele.World.RoomActions.TriggerTest.FakeRoom do
  @moduledoc """
  `{:global, {Kalevala.World.Room, room_id}}` 最小替身（同 `KnockPullTest.FakeRoom`）。
  全模块只注册一次（`setup_all` 起、`setup` 复位）。
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
end

defmodule Kantele.World.RoomActions.TriggerTest do
  @moduledoc """
  P5-4am：触发器型 `do_*` 一批（8 个房间 / 9 个 handler）的移植测试。

  共用 `RoomActions.Trigger` 共享原语：参数校验 → 条件门控（臂力/内力/武器/
  钥匙/火折/临时标记）→ 开出口（多数定时自关）→ 扣内力/消耗物品。

  跳过 `huanggong:shufang`（暗门目标 `huanggong:mishi` 在 LPC 源中不存在）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Beijing.AofuShufang.Turn, as: AofuTurn
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Gumu.Mishi1.Ci, as: MishiCi
  alias Kantele.World.RoomActions.Gumu.Mishi1.Zhan, as: MishiZhan
  alias Kantele.World.RoomActions.Heimuya.Huoting.Circle, as: HuotingCircle
  alias Kantele.World.RoomActions.Hengyang.Inhole2.Use, as: Inhole2Use
  alias Kantele.World.RoomActions.Jingzhou.Houyuan.Unlock, as: HouyuanUnlock
  alias Kantele.World.RoomActions.Shenlong.Lin1.Kan, as: Lin1Kan
  alias Kantele.World.RoomActions.TriggerTest.FakeRoom
  alias Kantele.World.RoomActions.Xiakedao.Gudi.Mai, as: GudiMai
  alias Kantele.World.RoomActions.Xueshan.Chanshi.Turn, as: ChanshiTurn

  @room_ids [
    "heimuya:huoting",
    "heimuya:didao1",
    "shenlong:lin1",
    "xiakedao:gudi",
    "beijing:aofu_shufang",
    "xueshan:chanshi",
    "jingzhou:houyuan",
    "hengyang:inhole2",
    "gumu:mishi1"
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
    test "八房九个 handler 都已注册" do
      assert RoomActionHandlers.lookup("heimuya:huoting", "do_circle") ==
               {:ok, {HuotingCircle, :run}}

      assert RoomActionHandlers.lookup("shenlong:lin1", "do_kan") == {:ok, {Lin1Kan, :run}}
      assert RoomActionHandlers.lookup("xiakedao:gudi", "do_mai") == {:ok, {GudiMai, :run}}
      assert RoomActionHandlers.lookup("beijing:aofu_shufang", "do_turn") == {:ok, {AofuTurn, :run}}

      assert RoomActionHandlers.lookup("xueshan:chanshi", "do_turn") ==
               {:ok, {ChanshiTurn, :run}}

      assert RoomActionHandlers.lookup("jingzhou:houyuan", "do_unlock") ==
               {:ok, {HouyuanUnlock, :run}}

      assert RoomActionHandlers.lookup("hengyang:inhole2", "do_use") == {:ok, {Inhole2Use, :run}}
      assert RoomActionHandlers.lookup("gumu:mishi1", "do_ci") == {:ok, {MishiCi, :run}}
      assert RoomActionHandlers.lookup("gumu:mishi1", "do_zhan") == {:ok, {MishiZhan, :run}}
    end
  end

  # ---- heimuya:huoting（旋碗开/关侧墙洞口，双向） ----

  describe "heimuya:huoting（circle wan 旋碗，双向切换）" do
    test "错词 → 你要旋什么" do
      conn = HuotingCircle.run(conn("heimuya:huoting", str: 20), params("heimuya:huoting", "bowl"))
      assert output(conn) == ["你要旋什么？\n"]
      refute DynamicExit.open?("heimuya:huoting", "down")
    end

    test "臂力不足 12 → 旋不开" do
      # `Stats.new()` 默认带 60 级 unarmed，`query_str` 含 div(max_melee_skill,10)=6 加成，
      # 故 str=0 → query_str=6 < 12。
      conn = HuotingCircle.run(conn("heimuya:huoting", str: 0), params("heimuya:huoting", "wan"))
      assert output(conn) == ["你臂力连旋不开什么！\n"]
      refute DynamicExit.open?("heimuya:huoting", "down")
    end

    test "circle wan → 开 down↔didao1 双向 + 广播 + 抓紧时间提示" do
      subscribe_room("heimuya:huoting")

      conn = HuotingCircle.run(conn("heimuya:huoting", str: 12), params("heimuya:huoting", "wan"))

      assert DynamicExit.open?("heimuya:huoting", "down")
      assert exit_target("heimuya:huoting", "down") == "heimuya:didao1"
      assert DynamicExit.open?("heimuya:didao1", "out")
      assert exit_target("heimuya:didao1", "out") == "heimuya:huoting"

      assert published(conn) == ["{npc}将碗旋开，见侧墙打开露，出一个黑幽幽的洞口.\n"]
      assert output(conn) == ["一定要抓紧时间，走后将它关上。\n"]
      # 无定时自关（LPC 无 call_out）
      refute Room.get_state_by_id("heimuya:huoting", "exit_timer:trigger:heimuya:huoting")
    end

    test "已开再 circle wan → 关双向 + 两边播报" do
      subscribe_room("heimuya:huoting")
      subscribe_room("heimuya:didao1")

      conn =
        HuotingCircle.run(
          conn("heimuya:huoting", str: 12),
          params("heimuya:huoting", "wan")
        )

      conn = HuotingCircle.run(conn, params("heimuya:huoting", "wan"))

      refute DynamicExit.open?("heimuya:huoting", "down")
      refute DynamicExit.open?("heimuya:didao1", "out")
      # 第二次调用只播关闭文案（conn 复用，channel_changes 累积，取最后一条）
      assert List.last(published(conn)) == "很快碗又搬回了原位。侧墙上的洞口又被封住了。\n"

      assert_received {:room_message, msg}, 200
      assert msg == "外面传来一阵搬动碗的声音，洞口被封住了。\n"
    end
  end

  # ---- shenlong:lin1（砍灌木开路） ----

  describe "shenlong:lin1（kan bush 砍灌木）" do
    test "错词 → 你要砍什么" do
      conn = Lin1Kan.run(conn("shenlong:lin1"), params("shenlong:lin1", "tree"))
      assert output(conn) == ["你要砍什么？\n"]
      refute DynamicExit.open?("shenlong:lin1", "north")
    end

    test "没拿武器 → 不用武器恐怕不行吧" do
      conn = Lin1Kan.run(conn("shenlong:lin1"), params("shenlong:lin1", "bush"))
      assert output(conn) == ["不用武器恐怕不行吧！\n"]
      refute DynamicExit.open?("shenlong:lin1", "north")
    end

    test "武器不是刀/剑 → 也能用来砍东西？" do
      conn =
        Lin1Kan.run(
          conn("shenlong:lin1", weapon: "staff"),
          params("shenlong:lin1", "bush")
        )

      assert output(conn) == ["桃木杖也能用来砍东西？\n"]
      refute DynamicExit.open?("shenlong:lin1", "north")
    end

    test "内力不足 → 没砍开路 + 内力清零" do
      conn = Lin1Kan.run(conn("shenlong:lin1", neili: 100, weapon: "sword"), params("shenlong:lin1", "bush"))

      # LPC 先播「乱砍」再判内力，两条都播
      assert published(conn) == [
               "{npc}抽出兵刃，对着灌木丛就是一阵乱砍。\n",
               "{npc}累得气喘吁吁,也没砍开一条路来。\n"
             ]

      assert neili_of(conn) == 0
      refute DynamicExit.open?("shenlong:lin1", "north")
    end

    test "kan bush（持剑 + 内力充足）→ 开 north→lin2 + 扣 50 + 20s 定时器" do
      conn =
        Lin1Kan.run(
          conn("shenlong:lin1", neili: 150, weapon: "blade"),
          params("shenlong:lin1", "bush")
        )

      assert DynamicExit.open?("shenlong:lin1", "north")
      assert exit_target("shenlong:lin1", "north") == "shenlong:lin2"
      assert published(conn) |> Enum.any?(&(&1 =~ "终于砍出一条小路"))
      assert neili_of(conn) == 100
      assert {:once, _ref} =
               Room.get_state_by_id("shenlong:lin1", "exit_timer:trigger:shenlong:lin1")
    end

    test "20 秒后灌木合拢自关" do
      Lin1Kan.run(conn("shenlong:lin1", neili: 150, weapon: "sword"), params("shenlong:lin1", "bush"))

      :ok =
        DynamicExit.do_close_after(
          [{"shenlong:lin1", "north", "灌木丛渐渐合拢起来,终于又恢复了原状。\n"}],
          false
        )

      refute DynamicExit.open?("shenlong:lin1", "north")
    end
  end

  # ---- xiakedao:gudi（埋骨掘墓） ----

  describe "xiakedao:gudi（mai gu 埋骨）" do
    test "错词 → 什么？" do
      conn = GudiMai.run(conn("xiakedao:gudi"), params("xiakedao:gudi", "stone"))
      assert output(conn) == ["什么？\n"]
      refute DynamicExit.open?("xiakedao:gudi", "east")
    end

    test "内力不足 → 挖不动 + 内力清零" do
      conn = GudiMai.run(conn("xiakedao:gudi", neili: 100), params("xiakedao:gudi", "gu"))

      # LPC 先播「用力挖」再判内力，两条都播
      assert published(conn) == [
               "{npc}找了一块松软的地面，用力挖了起来。\n",
               "{npc}的气力不足，挖了几下就干不动了。\n"
             ]

      assert neili_of(conn) == 0
      refute DynamicExit.open?("xiakedao:gudi", "east")
    end

    test "mai gu（内力充足）→ 开 east→midao6 + 扣 100 + 5s 定时器" do
      conn = GudiMai.run(conn("xiakedao:gudi", neili: 200), params("xiakedao:gudi", "gu"))

      assert DynamicExit.open?("xiakedao:gudi", "east")
      assert exit_target("xiakedao:gudi", "east") == "xiakedao:midao6"
      assert published(conn) |> Enum.any?(&(&1 =~ "恭恭敬敬的把老者的遗骨放了进去"))
      assert neili_of(conn) == 100
      assert {:once, _ref} =
               Room.get_state_by_id("xiakedao:gudi", "exit_timer:trigger:xiakedao:gudi")
    end

    test "bury gu 同一函数（别名动词）" do
      GudiMai.run(conn("xiakedao:gudi", neili: 200), params("xiakedao:gudi", "gu", "bury"))
      assert DynamicExit.open?("xiakedao:gudi", "east")
    end

    test "5 秒后石门自关" do
      GudiMai.run(conn("xiakedao:gudi", neili: 200), params("xiakedao:gudi", "gu"))

      :ok =
        DynamicExit.do_close_after(
          [{"xiakedao:gudi", "east", "石门自动的合上了。\n"}],
          false
        )

      refute DynamicExit.open?("xiakedao:gudi", "east")
    end
  end

  # ---- beijing:aofu_shufang（转把手开暗门） ----

  describe "beijing:aofu_shufang（turn bashou 转把手）" do
    test "错词 → :not_handled（放行全局 turn）" do
      assert AofuTurn.run(conn("beijing:aofu_shufang"), params("beijing:aofu_shufang", "hua")) ==
               :not_handled
    end

    test "没掀画卷（无 marks/画2）→ :not_handled" do
      assert AofuTurn.run(conn("beijing:aofu_shufang"), params("beijing:aofu_shufang", "bashou")) ==
               :not_handled

      refute DynamicExit.open?("beijing:aofu_shufang", "down")
    end

    test "turn bashou（已掀画卷）→ 开 down→aofu_mishi + 8s 定时器" do
      conn =
        AofuTurn.run(
          conn("beijing:aofu_shufang", temp: %{"marks/画2" => 1}),
          params("beijing:aofu_shufang", "bashou")
        )

      assert DynamicExit.open?("beijing:aofu_shufang", "down")
      assert exit_target("beijing:aofu_shufang", "down") == "beijing:aofu_mishi"
      assert published(conn) == ["{npc}拉了拉把手，地面忽然「喀喀喀」现出一个洞口。\n"]
      assert {:once, _ref} =
               Room.get_state_by_id("beijing:aofu_shufang", "exit_timer:trigger:beijing:aofu_shufang")
    end

    test "已开 → 你拉了拉把手，但似乎没什么作用" do
      conn =
        AofuTurn.run(
          conn("beijing:aofu_shufang", temp: %{"marks/画2" => 1}),
          params("beijing:aofu_shufang", "bashou")
        )

      conn = AofuTurn.run(conn, params("beijing:aofu_shufang", "bashou"))
      assert output(conn) == ["你拉了拉把手，但似乎没什么作用。\n"]
    end
  end

  # ---- xueshan:chanshi（转轮盘开地洞） ----

  describe "xueshan:chanshi（turn lunpan 转轮盘）" do
    test "错词 → 你要转动什么" do
      conn = ChanshiTurn.run(conn("xueshan:chanshi"), params("xueshan:chanshi", "stone"))
      assert output(conn) == ["你要转动什么？\n"]
      refute DynamicExit.open?("xueshan:chanshi", "down")
    end

    test "turn lunpan → 开 down→midao + 8s 定时器" do
      conn = ChanshiTurn.run(conn("xueshan:chanshi"), params("xueshan:chanshi", "lunpan"))

      assert DynamicExit.open?("xueshan:chanshi", "down")
      assert exit_target("xueshan:chanshi", "down") == "xueshan:midao"
      assert published(conn) == ["{npc}使劲转动轮盘，地面忽然「喀喀喀」现出一个洞口。\n"]
      assert {:once, _ref} =
               Room.get_state_by_id("xueshan:chanshi", "exit_timer:trigger:xueshan:chanshi")
    end
  end

  # ---- jingzhou:houyuan（钥匙开门） ----

  describe "jingzhou:houyuan（unlock men/east 钥匙开门）" do
    test "错词 → 你要打开什么" do
      conn = HouyuanUnlock.run(conn("jingzhou:houyuan"), params("jingzhou:houyuan", "gate"))
      assert output(conn) == ["你要打开什么？\n"]
      refute DynamicExit.open?("jingzhou:houyuan", "east")
    end

    test "没钥匙 → 你不会撬锁" do
      conn = HouyuanUnlock.run(conn("jingzhou:houyuan"), params("jingzhou:houyuan", "men"))
      assert output(conn) == ["你不会撬锁。\n"]
      refute DynamicExit.open?("jingzhou:houyuan", "east")
    end

    test "unlock men（带钥匙）→ 开 east→dongxiang + 钥匙消耗 + 无定时器" do
      conn =
        HouyuanUnlock.run(
          conn("jingzhou:houyuan", inventory: [key()]),
          params("jingzhou:houyuan", "men")
        )

      assert DynamicExit.open?("jingzhou:houyuan", "east")
      assert exit_target("jingzhou:houyuan", "east") == "jingzhou:dongxiang"
      assert published(conn) == ["{npc}用一把钥匙打开房门，可是钥匙却断了。\n"]
      assert character_of(conn).inventory == []
      refute Room.get_state_by_id("jingzhou:houyuan", "exit_timer:trigger:jingzhou:houyuan")
    end

    test "unlock east 同函数（别名参数）" do
      HouyuanUnlock.run(
        conn("jingzhou:houyuan", inventory: [key()]),
        params("jingzhou:houyuan", "east")
      )

      assert DynamicExit.open?("jingzhou:houyuan", "east")
    end

    test "已开 → 这扇门已经是打开的" do
      HouyuanUnlock.run(
        conn("jingzhou:houyuan", inventory: [key()]),
        params("jingzhou:houyuan", "men")
      )

      conn =
        HouyuanUnlock.run(
          conn("jingzhou:houyuan", inventory: [key()]),
          params("jingzhou:houyuan", "men")
        )

      assert output(conn) == ["这扇门已经是打开的。\n"]
    end
  end

  # ---- hengyang:inhole2（点火折照洞） ----

  describe "hengyang:inhole2（use fire 点火折）" do
    test "错词 → :not_handled（放行全局 use）" do
      assert Inhole2Use.run(conn("hengyang:inhole2"), params("hengyang:inhole2", "torch")) ==
               :not_handled
    end

    test "没火折 → :not_handled" do
      assert Inhole2Use.run(conn("hengyang:inhole2"), params("hengyang:inhole2", "fire")) ==
               :not_handled

      refute DynamicExit.open?("hengyang:inhole2", "west")
    end

    test "use fire（带火折）→ 开 west→zigai1 + north→zigai2 + 记 marks/走1，无定时器" do
      conn =
        Inhole2Use.run(
          conn("hengyang:inhole2", inventory: [fire()]),
          params("hengyang:inhole2", "fire")
        )

      assert DynamicExit.open?("hengyang:inhole2", "west")
      assert exit_target("hengyang:inhole2", "west") == "hengyang:zigai1"
      assert DynamicExit.open?("hengyang:inhole2", "north")
      assert exit_target("hengyang:inhole2", "north") == "hengyang:zigai2"
      assert output(conn) == ["\n你点燃了火折，发现这里有出口。\n\n"]
      assert character_of(conn).meta.temp["marks/走1"] == 1
      # 永久开启（LPC 靠 reset 回收），无定时器
      refute Room.get_state_by_id("hengyang:inhole2", "exit_timer:trigger:hengyang:inhole2")
    end
  end

  # ---- gumu:mishi1（刺砖探空 + 粘砖开门） ----

  describe "gumu:mishi1（ci brick 刺砖 + zhan brick 粘砖）" do
    test "ci 错词 → 你要刺什么" do
      conn = MishiCi.run(conn("gumu:mishi1"), params("gumu:mishi1", "wall", "ci"))
      assert output(conn) == ["你要刺什么？\n"]
    end

    test "ci 没拿家伙 → 要刺墙不用家伙恐怕不行吧" do
      conn = MishiCi.run(conn("gumu:mishi1"), params("gumu:mishi1", "brick", "ci"))
      assert output(conn) == ["要刺墙不用家伙恐怕不行吧！\n"]
    end

    test "ci brick（持械）→ 广播 + 置 tmarks/砖" do
      conn =
        MishiCi.run(
          conn("gumu:mishi1", weapon: "sword"),
          params("gumu:mishi1", "brick", "ci")
        )

      assert published(conn) == ["{npc}拔出兵刃，向青砖轻轻刺去，只听得空空作声，青砖的另一头仿佛是空的。\n"]
      assert character_of(conn).meta.temp["tmarks/砖"] == 1
    end

    test "zhan 错词 → 你要粘住什么" do
      conn = MishiZhan.run(conn("gumu:mishi1"), params("gumu:mishi1", "wall", "zhan"))
      assert output(conn) == ["你要粘住什么？\n"]
      refute DynamicExit.open?("gumu:mishi1", "down")
    end

    test "zhan 未探空（无 tmarks/砖）→ 你要粘住什么" do
      conn = MishiZhan.run(conn("gumu:mishi1"), params("gumu:mishi1", "brick", "zhan"))
      assert output(conn) == ["你要粘住什么？\n"]
      refute DynamicExit.open?("gumu:mishi1", "down")
    end

    test "zhan brick（已探空）→ 开 down→houting + 5s 定时器 + tmarks/砖 归零" do
      conn =
        MishiZhan.run(
          conn("gumu:mishi1", temp: %{"tmarks/砖" => 1}),
          params("gumu:mishi1", "brick", "zhan")
        )

      assert DynamicExit.open?("gumu:mishi1", "down")
      assert exit_target("gumu:mishi1", "down") == "gumu:houting"
      assert published(conn) |> Enum.any?(&(&1 =~ "墙壁上就现出了一个大洞"))
      assert character_of(conn).meta.temp["tmarks/砖"] == 0
      assert {:once, _ref} =
               Room.get_state_by_id("gumu:mishi1", "exit_timer:trigger:gumu:mishi1")
    end

    test "zhan 用完后须再 ci 才能再开" do
      conn =
        MishiZhan.run(
          conn("gumu:mishi1", temp: %{"tmarks/砖" => 1}),
          params("gumu:mishi1", "brick", "zhan")
        )

      conn = MishiZhan.run(conn, params("gumu:mishi1", "brick", "zhan"))
      assert output(conn) == ["你要粘住什么？\n"]
    end

    test "5 秒后落砖自关" do
      MishiZhan.run(
        conn("gumu:mishi1", temp: %{"tmarks/砖" => 1}),
        params("gumu:mishi1", "brick", "zhan")
      )

      :ok =
        DynamicExit.do_close_after(
          [{"gumu:mishi1", "down", "\n过不多一会儿，梁上落下几块青砖，又将墙上的洞遮住了。\n"}],
          false
        )

      refute DynamicExit.open?("gumu:mishi1", "down")
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp params(room_id, arg, verb \\ "do") do
    %{verb: verb, trailing: arg, room_id: room_id}
  end

  defp conn(room_id, opts \\ []) do
    neili = Keyword.get(opts, :neili, 200)
    str = Keyword.get(opts, :str, 20)
    temp = Keyword.get(opts, :temp, %{})
    weapon = Keyword.get(opts, :weapon)
    inventory = Keyword.get(opts, :inventory, [])

    vitals = %{Vitals.new() | neili: neili, max_neili: neili}
    stats = %{Stats.new() | str: str}
    combat = if weapon, do: Combat.equip(Combat.new(), :weapon, weapon_snapshot(weapon)), else: Combat.new()

    character = %Kalevala.Character{
      id: "test-player",
      name: "玩家",
      room_id: room_id,
      attributes: %{"wiz_level" => 0},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        damage: %{},
        temp: temp,
        env: %{}
      },
      inventory: inventory
    }

    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp weapon_snapshot("sword"), do: %{name: "青锋剑", skill_type: "sword", damage: 20, prop: nil}
  defp weapon_snapshot("blade"), do: %{name: "单刀", skill_type: "blade", damage: 15, prop: nil}
  defp weapon_snapshot("staff"), do: %{name: "桃木杖", skill_type: "staff", damage: 5, prop: nil}

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

  # `d/jingzhou/obj/guifang-key.c` 与 `d/xiyu/obj/fire.c`：按 alias 匹配
  defp key do
    %Kalevala.World.Item.Instance{
      id: "test-key-instance",
      item_id: "jingzhou:guifang_key",
      item: %Kalevala.World.Item{
        id: "jingzhou:guifang_key",
        name: "鬼房钥匙",
        meta: %{aliases: ["guifang key", "key"]}
      }
    }
  end

  defp fire do
    %Kalevala.World.Item.Instance{
      id: "test-fire-instance",
      item_id: "xiyu:fire",
      item: %Kalevala.World.Item{
        id: "xiyu:fire",
        name: "火折",
        meta: %{aliases: ["fire", "huozhe"]}
      }
    }
  end
end

defmodule Kantele.World.RoomActions.TerrainMoveTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActionDispatcher
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.TerrainMove

  # ---- 测试夹具 ----

  defp meta(overrides) do
    overrides = if is_list(overrides), do: Map.new(overrides), else: overrides

    vitals =
      Map.merge(
        %{qi: 200, jing: 200, neili: 100, max_neili: 100, max_qi: 200, max_jing: 200},
        Map.get(overrides, :vitals, %{})
      )

    dodge = Map.get(overrides, :dodge, 200)
    stats = Stats.new() |> Map.put(:skills, Map.put(Stats.new().skills, "dodge", dodge))

    combat =
      %{Combat.new() | busy: Map.get(overrides, :busy, 0), enemies: Map.get(overrides, :enemies, [])}

    %PlayerMeta{
      vitals: vitals,
      stats: stats,
      combat: combat,
      temp: %{}
    }
  end

  defp conn_in(room_id, verb, handler, overrides \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        id: "c1",
        name: "测试",
        description: "测试角色",
        room_id: room_id,
        meta: meta(overrides)
      },
      private: %Private{
        room: %Room{id: room_id, key: "r", zone_id: "z", actions: %{verb => handler}},
        channel_changes: []
      },
      output: [],
      events: []
    }
  end

  defp dispatch(conn, text) do
    RoomActionDispatcher.dispatch(conn, text, &RoomActionHandlers.lookup/2)
  end

  defp texts(conn) do
    Enum.flat_map(conn.output, fn
      %Text{data: data} -> [data]
      _ -> []
    end)
  end

  defp publishes(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:publish, _c, _e, _o, _f}, &1))
    |> Enum.map(fn {:publish, channel, event, _opts, _err} -> {channel, event.data.text} end)
  end

  defp publish_metas(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:publish, _c, _e, _o, _f}, &1))
    |> Enum.map(fn {:publish, channel, event, _opts, _err} -> {channel, event.data.meta} end)
  end

  defp new_room(conn) do
    case conn.private.update_character do
      nil -> nil
      c -> c.room_id
    end
  end

  defp qi_of(conn) do
    char = conn.private.update_character || conn.character
    Map.get(char.meta.vitals, :qi, 0)
  end

  # ---- 覆盖度 ----

  describe "entries/0 覆盖度" do
    test "13 个 {room, verb} 表项（12 间房）" do
      assert Map.keys(TerrainMove.entries()) |> Enum.sort() == [
               {"hengyang:outzhushendong", "climb"},
               {"hengyang:outzigai", "climb"},
               {"hengyang:outzigai", "jump"},
               {"hengyang:outzigai1", "jump"},
               {"hengyang:shuiliandong", "jump"},
               {"hengyang:xuanyadi", "climb"},
               {"jueqing:eyutan1", "cross"},
               {"jueqing:eyutan2", "swim"},
               {"jueqing:eyutan3", "cross"},
               {"jueqing:ontree1", "jump"},
               {"jueqing:ontree3", "climb"},
               {"jueqing:undertan", "climb"},
               {"jueqing:underya2", "jump"}
             ]
    end
  end

  # ---- hengyang:outzhushendong do_climb（qi 门控）----

  describe "hengyang:outzhushendong do_climb（拉树藤到石林峰，qi<100 摔落）" do
    test "climb teng，qi 充足 → 旧房广播 + 新房到达广播（排除行动者）+ 瞬移 shilinfeng" do
      conn = conn_in("hengyang:outzhushendong", "climb", "do_climb", vitals: %{qi: 200})

      assert {:handled, conn2} = dispatch(conn, "climb teng")

      assert publishes(conn2) == [
               {"rooms:hengyang:outzhushendong", "\n{npc}拉着树藤往峭壁上爬去。\n"},
               {"rooms:hengyang:shilinfeng", "\n{npc}从峭壁下面爬了上来。\n"}
             ]

      assert publish_metas(conn2) == [
               {"rooms:hengyang:outzhushendong", %{}},
               {"rooms:hengyang:shilinfeng", %{exclude_actor: true}}
             ]

      assert new_room(conn2) == "hengyang:shilinfeng"
    end

    test "climb teng，qi<100 → 合并广播（摔落）+ 昏厥，不移动" do
      conn = conn_in("hengyang:outzhushendong", "climb", "do_climb", vitals: %{qi: 50})

      assert {:handled, conn2} = dispatch(conn, "climb teng")

      assert Enum.any?(publishes(conn2), fn {_c, t} ->
               String.contains?(t, "体力不知，从峭壁上摔了下来")
             end)

      assert qi_of(conn2) == 0
      assert new_room(conn2) == "hengyang:outzhushendong"
    end

    test "别名 pa teng 与 climb teng 同效（动词归一化）" do
      conn = conn_in("hengyang:outzhushendong", "pa", "do_climb", vitals: %{qi: 200})

      assert {:handled, conn2} = dispatch(conn, "pa teng")
      assert new_room(conn2) == "hengyang:shilinfeng"
    end

    test "参数不符 → 私发提示，不移动" do
      conn = conn_in("hengyang:outzhushendong", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb rock")
      assert texts(conn2) == ["你想往哪儿爬？\n"]
      assert new_room(conn2) == nil
    end
  end

  # ---- hengyang:outzigai do_climb / do_tiao ----

  describe "hengyang:outzigai do_climb / do_tiao" do
    test "climb stone → 玩家私发提示 + 瞬移 outzigai1（无房间广播）" do
      conn = conn_in("hengyang:outzigai", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb stone")

      assert texts(conn2) == [
               "\n你走到洞壁旁，手拉上面突石，脚踩下面突石，不一会而便到了高处。\n\n"
             ]

      assert publishes(conn2) == []
      assert new_room(conn2) == "hengyang:outzigai1"
    end

    test "tiao stone → 旧房广播 + 昏厥，不移动" do
      conn = conn_in("hengyang:outzigai", "tiao", "do_tiao")

      assert {:handled, conn2} = dispatch(conn, "tiao stone")

      assert Enum.any?(publishes(conn2), fn {_c, t} ->
               String.contains?(t, "摔了下来，顿时晕了过去")
             end)

      assert qi_of(conn2) == 0
      assert new_room(conn2) == "hengyang:outzigai"
    end
  end

  # ---- hengyang:outzigai1 do_tiao（往下跳回突石盖）----
  #
  # 这间房的 `down` 出口被 `valid_leave` 拦住（「这里又没有路，看来只有跳下去了」），
  # 所以缺这个 handler 玩家会被困在突石上。

  describe "hengyang:outzigai1 do_tiao（往下跳）" do
    test "轻功<120 → 旧房广播 + 摔落昏厥 + 瞬移 outzigai" do
      conn = conn_in("hengyang:outzigai1", "tiao", "do_tiao", dodge: 60)

      assert {:handled, conn2} = dispatch(conn, "tiao down")

      assert publishes(conn2) == [
               {"rooms:hengyang:outzigai1", "\n{npc}鼓起勇气纵身往下一跳...\n"},
               {"rooms:hengyang:outzigai", "{npc}从上面摔了下来，昏倒了。\n"}
             ]

      assert qi_of(conn2) == 0
      assert new_room(conn2) == "hengyang:outzigai"
    end

    test "轻功>=120 → 稳稳落地，到达广播排除行动者" do
      conn = conn_in("hengyang:outzigai1", "tiao", "do_tiao", dodge: 150)

      assert {:handled, conn2} = dispatch(conn, "tiao down")

      assert publishes(conn2) == [
               {"rooms:hengyang:outzigai1", "\n{npc}你纵身一跳，稳稳地落在了地上。\n\n"},
               {"rooms:hengyang:outzigai", "{npc}从上面跳了下来。\n"}
             ]

      assert publish_metas(conn2) == [
               {"rooms:hengyang:outzigai1", %{}},
               {"rooms:hengyang:outzigai", %{exclude_actor: true}}
             ]

      assert qi_of(conn2) == 200
      assert new_room(conn2) == "hengyang:outzigai"
    end

    test "jump down 与 tiao down 同义" do
      conn = conn_in("hengyang:outzigai1", "jump", "do_tiao", dodge: 150)

      assert {:handled, conn2} = dispatch(conn, "jump down")
      assert new_room(conn2) == "hengyang:outzigai"
    end

    test "参数不是 down → 私发提示，不移动" do
      conn = conn_in("hengyang:outzigai1", "tiao", "do_tiao")

      assert {:handled, conn2} = dispatch(conn, "tiao up")

      assert texts(conn2) == ["你要往哪儿跳？\n"]
      assert new_room(conn2) == nil
    end
  end

  # ---- hengyang:shuiliandong do_tiao（按轻功分三档）----

  describe "hengyang:shuiliandong do_tiao（跳瀑布，轻功分三档）" do
    test "轻功<60 → 旧房广播 + 玩家私发 + 瞬移 heishatan + 昏厥" do
      conn = conn_in("hengyang:shuiliandong", "tiao", "do_tiao", dodge: 30)

      assert {:handled, conn2} = dispatch(conn, "tiao pubu")

      assert Enum.any?(publishes(conn2), fn {c, t} ->
               c == "rooms:hengyang:shuiliandong" and String.contains?(t, "被瀑布冲了下去")
             end)

      assert Enum.any?(texts(conn2), &String.contains?(&1, "迷迷糊糊"))
      assert qi_of(conn2) == 0
      assert new_room(conn2) == "hengyang:heishatan"
    end

    test "60<=轻功<140 → 旧房广播 + 新房到达广播（排除行动者）+ 瞬移 inhole" do
      conn = conn_in("hengyang:shuiliandong", "tiao", "do_tiao", dodge: 100)

      assert {:handled, conn2} = dispatch(conn, "tiao 瀑布")

      assert publishes(conn2) == [
               {"rooms:hengyang:shuiliandong",
                "\n{npc}奋力往前一跳，险些被瀑布打落，但有惊无险，{npc}终于落在洞口处，可样子却甚是狼狈。\n\n"},
               {"rooms:hengyang:inhole", "\n{npc}从瀑布外跳狼狈万分地跳了进来。\n\n"}
             ]

      assert publish_metas(conn2) == [
               {"rooms:hengyang:shuiliandong", %{}},
               {"rooms:hengyang:inhole", %{exclude_actor: true}}
             ]

      assert new_room(conn2) == "hengyang:inhole"
    end

    test "轻功>=140 → 轻松落洞 + 瞬移 inhole" do
      conn = conn_in("hengyang:shuiliandong", "jump", "do_tiao", dodge: 200)

      assert {:handled, conn2} = dispatch(conn, "jump pubu")

      assert publishes(conn2) == [
               {"rooms:hengyang:shuiliandong", "\n{npc}提气向前一纵，轻松地落在洞口处。\n\n"},
               {"rooms:hengyang:inhole", "\n{npc}从瀑布外跳了进来。\n"}
             ]

      assert new_room(conn2) == "hengyang:inhole"
    end
  end

  # ---- hengyang:xuanyadi do_climb ----

  describe "hengyang:xuanyadi do_climb（teng 需 qi；tree 静默位移）" do
    test "climb teng，qi 充足 → 旧房 + 新房到达（排除行动者）+ 瞬移 zigai" do
      conn = conn_in("hengyang:xuanyadi", "climb", "do_climb", vitals: %{qi: 200})

      assert {:handled, conn2} = dispatch(conn, "climb teng")

      assert publishes(conn2) == [
               {"rooms:hengyang:xuanyadi", "\n{npc}拉着树藤往峭壁上爬去。\n"},
               {"rooms:hengyang:zigai", "\n{npc}从峭壁下面爬了上来。\n"}
             ]

      assert publish_metas(conn2) == [
               {"rooms:hengyang:xuanyadi", %{}},
               {"rooms:hengyang:zigai", %{exclude_actor: true}}
             ]

      assert new_room(conn2) == "hengyang:zigai"
    end

    test "climb teng，qi<100 → 摔落 + 昏厥，不移动" do
      conn = conn_in("hengyang:xuanyadi", "climb", "do_climb", vitals: %{qi: 50})

      assert {:handled, conn2} = dispatch(conn, "climb teng")

      assert Enum.any?(publishes(conn2), &String.contains?(elem(&1, 1), "摔了下来"))
      assert qi_of(conn2) == 0
      assert new_room(conn2) == "hengyang:xuanyadi"
    end

    test "climb tree → 静默瞬移 ontree（无任何广播/提示）" do
      conn = conn_in("hengyang:xuanyadi", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb tree")

      assert publishes(conn2) == []
      assert texts(conn2) == []
      assert new_room(conn2) == "hengyang:ontree"
    end
  end

  # ---- jueqing:eyutan1 / eyutan3 do_cross（轻功穿潭）----

  describe "jueqing:eyutan1 / eyutan3 do_cross（轻功>120 过潭，否则落深潭）" do
    # 判据是 LPC `query_skill("dodge")`（有效等级）＝ div(基本,2) + 特技 + apply，
    # 所以 dodge 260 → 有效 130（过），dodge 240 → 有效 120（不过，需 > 120）。
    test "eyutan1 cross tan，轻功>120 → 旧房(排除行动者)+玩家私发+新房到达+瞬移 eyutan3" do
      conn = conn_in("jueqing:eyutan1", "cross", "do_cross", dodge: 260)

      assert {:handled, conn2} = dispatch(conn, "cross tan")

      assert publishes(conn2) == [
               {"rooms:jueqing:eyutan1",
                "{npc}飞身前跃，跳向鄂鱼潭，只见{npc}到至深潭上空却又忽地落下，眼见要坠入潭中。却见{npc}双足在鄂鱼背上一点，顷刻间腾向对岸。\n"},
               {"rooms:jueqing:eyutan3", "{npc}从对岸跳了过来。\n"}
             ]

      assert publish_metas(conn2) == [
               {"rooms:jueqing:eyutan1", %{exclude_actor: true}},
               {"rooms:jueqing:eyutan3", %{exclude_actor: true}}
             ]

      assert Enum.any?(texts(conn2), &String.contains?(&1, "眨眼间已到得对岸"))
      assert new_room(conn2) == "jueqing:eyutan3"
    end

    test "eyutan1 cross tan，轻功<=120 → 旧房(排除行动者)+玩家私发+瞬移 eyutan2（无到达广播）" do
      conn = conn_in("jueqing:eyutan1", "cross", "do_cross", dodge: 240)

      assert {:handled, conn2} = dispatch(conn, "cross tan")

      assert publishes(conn2) == [
               {"rooms:jueqing:eyutan1",
                "{npc}飞身前跃，跳向鄂鱼潭，只见{npc}到至深潭上空却力气已尽，落入潭中。\n"}
             ]

      assert publish_metas(conn2) == [{"rooms:jueqing:eyutan1", %{exclude_actor: true}}]
      assert Enum.any?(texts(conn2), &String.contains?(&1, "落入深潭之中"))
      assert new_room(conn2) == "jueqing:eyutan2"
    end

    test "eyutan3 cross tan，轻功>120 → 瞬移 eyutan1；<=120 → 瞬移 eyutan2" do
      conn_ok = conn_in("jueqing:eyutan3", "cross", "do_cross", dodge: 260)
      assert {:handled, ok2} = dispatch(conn_ok, "cross tan")
      assert new_room(ok2) == "jueqing:eyutan1"

      conn_bad = conn_in("jueqing:eyutan3", "cross", "do_cross", dodge: 240)
      assert {:handled, bad2} = dispatch(conn_bad, "cross tan")
      assert new_room(bad2) == "jueqing:eyutan2"
    end
  end

  # ---- jueqing:eyutan2 do_swim ----

  describe "jueqing:eyutan2 do_swim（游回岸上）" do
    test "swim bank → 玩家私发 + 新房到达（排除行动者）+ 瞬移 eyutan1" do
      conn = conn_in("jueqing:eyutan2", "swim", "do_swim")

      assert {:handled, conn2} = dispatch(conn, "swim bank")

      assert publishes(conn2) == [{"rooms:jueqing:eyutan1", "{npc}游了上来。\n"}]
      assert publish_metas(conn2) == [{"rooms:jueqing:eyutan1", %{exclude_actor: true}}]
      assert texts(conn2) == ["你使尽所有力气向岸边游去…\n"]
      assert new_room(conn2) == "jueqing:eyutan1"
    end

    test "别名 you bank 与 swim bank 同效" do
      conn = conn_in("jueqing:eyutan2", "you", "do_swim")
      assert {:handled, conn2} = dispatch(conn, "you bank")
      assert new_room(conn2) == "jueqing:eyutan1"
    end
  end

  # ---- jueqing:ontree1 / ontree3 / undertam / underya2 ----

  describe "jueqing 其余地形房" do
    test "ontree1 jump down → 新房到达（排除行动者）+ 瞬移 undertam" do
      conn = conn_in("jueqing:ontree1", "jump", "do_jump")

      assert {:handled, conn2} = dispatch(conn, "jump down")

      assert publishes(conn2) == [{"rooms:jueqing:undertan", "{npc}从大枣树上跳了下来。\n"}]
      assert publish_metas(conn2) == [{"rooms:jueqing:undertan", %{exclude_actor: true}}]
      assert new_room(conn2) == "jueqing:undertan"
    end

    test "ontree3 climb teng → 旧房广播 + 瞬移 ligui" do
      conn = conn_in("jueqing:ontree3", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb teng")

      assert publishes(conn2) == [{"rooms:jueqing:ontree3", "{npc}顺着树藤向上爬去…\n"}]
      assert new_room(conn2) == "jueqing:ligui"
    end

    test "undertan climb tree → 新房到达（排除行动者）+ 瞬移 ontree1" do
      conn = conn_in("jueqing:undertan", "climb", "do_climb")

      assert {:handled, conn2} = dispatch(conn, "climb tree")

      assert publishes(conn2) == [{"rooms:jueqing:ontree1", "{npc}从下面爬了上来。\n"}]
      assert publish_metas(conn2) == [{"rooms:jueqing:ontree1", %{exclude_actor: true}}]
      assert new_room(conn2) == "jueqing:ontree1"
    end

    test "underya2 jump tan → 玩家私发 + 瞬移 underya" do
      conn = conn_in("jueqing:underya2", "jump", "do_jump")

      assert {:handled, conn2} = dispatch(conn, "jump tan")

      assert texts(conn2) == [
               "你纵身入潭，顺势而下忙，向光亮处游去，过不多时，便到了寒潭另一侧，你迫不及待，纵身跃出水面。\n\n"
             ]

      assert publishes(conn2) == []
      assert new_room(conn2) == "jueqing:underya"
    end
  end

  # ---- 忙乱 / 战斗守卫 ----

  describe "忙乱 / 战斗守卫（eyutan1 cross）" do
    test "忙乱中 → 私发「正忙着」且不动" do
      conn = conn_in("jueqing:eyutan1", "cross", "do_cross", busy: 1)

      assert {:handled, conn2} = dispatch(conn, "cross tan")
      assert texts(conn2) == ["你现在正忙着呢！\n"]
      assert new_room(conn2) == nil
    end

    test "战斗中 → 私发「先解决面前这家伙」且不动" do
      conn = conn_in("jueqing:eyutan1", "cross", "do_cross", enemies: ["mob1"])

      assert {:handled, conn2} = dispatch(conn, "cross tan")
      assert texts(conn2) == ["你还是先把你面前这个家伙解决了再说。\n"]
      assert new_room(conn2) == nil
    end
  end

  # ---- 降级 ----

  describe "未配置降级" do
    test "未配置 {room, verb} → :not_handled" do
      conn = conn_in("some:other", "climb", "do_climb")
      assert :not_handled = dispatch(conn, "climb teng")
    end
  end
end

defmodule Kantele.Character.GanjiangEventTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.GanjiangEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @owner_id "player-gan-1"
  @owner_name "王五"

  setup do
    Forging.ensure_table()
    Forging.delete(@owner_id)

    Items.put("forge:xuantie", %Item{
      id: "forge:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{material_attrib: "steel", material_name: "玄铁", power_point: 100}
    })

    :ok
  end

  defp ganjiang do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{})

    %Character{
      id: Forging.ganjiang_id(),
      name: "干将 Ganjiang",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp session(extra \\ %{}) do
    %{
      status: "handoff",
      value: 2_200_000,
      material_item_id: "forge:xuantie",
      material_instance_id: "inst-xuantie",
      owner_id: @owner_id,
      owner_name: @owner_name,
      player_pid: self(),
      types: ["剑"],
      ctype: "剑",
      stype: "sword",
      unit: "柄",
      point: 100,
      prop: 0,
      wscale: 150
    }
    |> Map.merge(extra)
  end

  # 注入房间角色快照（生产走房间进程，测试走 `conn.private.room`）
  defp conn_in_room(character, ids) do
    characters = Enum.map(ids, fn id -> %{id: id, pid: self()} end)
    conn = build_conn(character)
    %{conn | private: %{conn.private | room: %{characters: characters}}}
  end

  defp material_instance, do: %Instance{id: "inst-xuantie", item_id: "forge:xuantie"}

  defp handoff(ids) do
    Forging.put(@owner_id, session())

    event =
      event(ganjiang(), "forge/handoff", %{
        material_instance: material_instance(),
        session: session()
      })

    GanjiangEvent.handoff(conn_in_room(ganjiang(), ids), event)
  end

  # `channel_changes` 是**倒序累积**的，这里还原成发布顺序
  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{data: data}, _opts, _fun} ->
        if Map.get(data, :type) == "vision", do: [data.text], else: []

      _ ->
        []
    end)
  end

  defp vision_count(conn), do: length(vision_texts(conn))
  defp last_vision(conn), do: List.last(vision_texts(conn))

  # 手动驱动下一跳：从邮箱取 `forge/step` 事件并交给 `step/2`
  defp next_step(conn, expected) do
    assert_receive %Kalevala.Event{topic: "forge/step", data: %{step: ^expected}} = event, 1_000
    GanjiangEvent.step(conn, event)
  end

  defp run_to_step_6(conn) do
    conn = next_step(conn, "prepare")
    conn = next_step(conn, 1)
    conn = next_step(conn, 2)
    conn = next_step(conn, 3)
    conn = next_step(conn, 4)
    conn = next_step(conn, 5)
    next_step(conn, 6)
  end

  describe "handoff（start_work）" do
    test "材料入包、status=waiting、can_help 未置、waited=4、1 秒后开炉" do
      conn = handoff([Forging.moye_id(), @owner_id])

      # LPC `start_work`：status 是 waiting，不是 inputing
      s = Forging.get(@owner_id)
      assert s.status == "waiting"
      refute s.can_help
      assert s.making_instance_id == "inst-xuantie"
      assert s.waited == 4

      # 材料计入干将背包
      updated = conn.private.update_character || conn.character
      assert Enum.any?(updated.inventory, &(&1.id == "inst-xuantie"))

      # handoff 本身不广播（prepare_make 在 1 秒后）
      assert vision_count(conn) == 0

      # 排了 prepare 这一跳
      assert_receive %Kalevala.Event{topic: "forge/step", data: %{step: "prepare"}}, 1_000
    end
  end

  describe "分步 vision（prepare → step 6）" do
    test "七段文案按序发出，$N 留 {npc}，材料/类型/单位已替换" do
      conn = handoff([Forging.moye_id(), @owner_id])

      conn = next_step(conn, "prepare")
      assert vision_count(conn) == 1
      v1 = last_vision(conn)
      assert v1 =~ "好，开炉锻炼"
      assert v1 =~ "玄铁 Xuantie"
      refute v1 =~ "$N"

      conn = next_step(conn, 1)
      assert vision_count(conn) == 2
      assert last_vision(conn) =~ "炉火渐渐的转成了绿色"
      assert last_vision(conn) =~ "注内力"
      # work_step_1 打开注内力窗口
      assert Forging.get(@owner_id).can_help == true

      conn = next_step(conn, 2)
      assert vision_count(conn) == 3
      assert last_vision(conn) =~ "一片红色"
      # work_step_2 关闭窗口
      assert Forging.get(@owner_id).can_help == false

      conn = next_step(conn, 3)
      assert last_vision(conn) =~ "成了剑的形状"

      conn = next_step(conn, 4)
      assert last_vision(conn) =~ "抛入水池"

      conn = next_step(conn, 5)
      assert last_vision(conn) =~ "满意地说，很好，很好"

      conn = next_step(conn, 6)
      assert vision_count(conn) == 7
      assert last_vision(conn) =~ "一柄好剑不能没有名字"

      # step 6 才进入 inputing，并排 240 秒等待
      s = Forging.get(@owner_id)
      assert s.status == "inputing"
      assert s.waited == 4

      # tell_rules 走私发（tell_object），不进房间频道
      assert_receive %Kalevala.Event{topic: "forge/notice", data: %{text: rules}}, 1_000
      assert rules =~ "干将在你耳边悄声说道"
      assert_receive %Kalevala.Event{topic: "forge/waiting"}, 1_000
    end

    test "玩家不在场时 work_step_1 不置 can_help" do
      conn = handoff([Forging.moye_id()])
      conn = next_step(conn, "prepare")
      _conn = next_step(conn, 1)

      refute Forging.get(@owner_id).can_help
    end
  end

  describe "work_step_6 的中止分支" do
    test "莫邪不在场 → 销毁半成品、清会话、不再广播" do
      conn = handoff([@owner_id])
      conn = run_to_step_6(conn)

      assert Forging.get(@owner_id) == nil
      # 只有前面 6 段，第 7 段（起名）没发
      assert vision_count(conn) == 6

      updated = conn.private.update_character || conn.character
      refute Enum.any?(updated.inventory, &(&1.id == "inst-xuantie"))
    end

    test "玩家离开房间 → 同样中止" do
      conn = handoff([Forging.moye_id()])
      _conn = run_to_step_6(conn)

      assert Forging.get(@owner_id) == nil
    end
  end

  describe "陈旧定时器" do
    test "令牌被后续排程替换后，旧事件不再生效" do
      Forging.put(@owner_id, session())

      stale = %Kalevala.Event{
        from_pid: self(),
        topic: "forge/step",
        data: %{owner_id: @owner_id, token: -1, step: 6}
      }

      conn = GanjiangEvent.step(build_conn(ganjiang()), stale)

      # 没有销毁、没有改状态
      assert Forging.get(@owner_id).status == "handoff"
      assert vision_count(conn) == 0
    end
  end
end

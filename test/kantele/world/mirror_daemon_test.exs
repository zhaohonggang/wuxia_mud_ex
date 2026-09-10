defmodule Kantele.World.MirrorDaemonTaskCarrierTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Item.Meta
  alias Kantele.World.Items
  alias Kantele.World.MirrorDaemon
  alias Kantele.World.MirrorDaemon.TaskCarrier
  alias Kantele.World.ZoneCache

  @allowed_rooms ["guangchang", "shanlu"]

  describe "TaskCarrier 模板" do
    test "build_carrier/3 数据完备：按级属性加强、背包携带 task 物品、无 loot 不重生" do
      task_def = %{owner: "张三", owner_id: "zhang", item_id: "liuxi:task/t1"}
      carrier = TaskCarrier.build_carrier("t1", task_def, "liuxi:shanlu")

      assert carrier.name == "张三"
      assert carrier.room_id == "liuxi:shanlu"
      assert String.starts_with?(carrier.id, "task-carrier-t1-")

      assert carrier.meta.kind == "task_carrier"
      assert carrier.meta.task_name == "t1"
      assert carrier.meta.task_item_id == "liuxi:task/t1"
      assert carrier.meta.zone_id == "liuxi"

      # 等级 1-15：qi 8000..36000，每级 qi+2000/sk_lvl+50
      level = div(carrier.meta.vitals.qi - 8_000, 2_000) + 1
      sk_lvl = 200 + (level - 1) * 50

      assert level in 1..15
      assert carrier.meta.vitals.qi in 8_000..36_000
      assert carrier.meta.vitals.max_qi == carrier.meta.vitals.qi
      assert carrier.meta.vitals.base_qi == carrier.meta.vitals.qi
      assert carrier.meta.vitals.jing == div(carrier.meta.vitals.qi, 2)
      assert carrier.meta.vitals.neili == div(carrier.meta.vitals.qi * 8, 5) * 2

      assert carrier.meta.stats.skills["unarmed"] == sk_lvl
      assert carrier.meta.stats.skills["dodge"] == sk_lvl
      assert carrier.meta.stats.skills["parry"] == sk_lvl
      assert carrier.meta.stats.skills["force"] == sk_lvl
      assert carrier.meta.combat_config.apply["attack"] == sk_lvl
      assert carrier.meta.combat_config.apply["damage"] == sk_lvl
      assert carrier.meta.combat_config.apply["armor"] == div(sk_lvl, 3)

      # 任务载体语义：被动、不重生、无掉落、背包恰好 1 个 task 物品
      assert carrier.meta.combat_config.attitude == "passive"
      assert carrier.meta.combat_config.respawn_delay == 0
      assert carrier.meta.combat_config.no_kill == false
      assert carrier.meta.loot == []
      assert [%Kalevala.World.Item.Instance{item_id: "liuxi:task/t1"}] = carrier.inventory
    end

    test "build_carrier/4 接受注入 zone_id（供测试/多区扩展）" do
      task_def = %{owner: "李四", owner_id: "li", item_id: "tz-9:task/t2"}
      carrier = TaskCarrier.build_carrier("t2", task_def, "tz-9:road", "tz-9")

      assert carrier.meta.zone_id == "tz-9"
      assert [%Kalevala.World.Item.Instance{item_id: "tz-9:task/t2"}] = carrier.inventory
    end
  end

  describe "MirrorDaemon 轮次生成（集成）" do
    setup do
      zone_id = "tmir-#{System.unique_integer([:positive])}"
      daemon = :"mirror_daemon_#{System.unique_integer([:positive])}"

      rooms =
        Enum.map(@allowed_rooms, fn key ->
          %Kantele.World.Room{
            id: "#{zone_id}:#{key}",
            key: key,
            zone_id: zone_id,
            name: key,
            description: "测试房间",
            x: -1,
            y: 2,
            z: 0,
            exits: [],
            features: [],
            flags: []
          }
        end)
        |> Kernel.++([
          %Kantele.World.Room{
            id: "#{zone_id}:heian",
            key: "heian",
            zone_id: zone_id,
            name: "黑道",
            description: "危险地带",
            x: 1,
            y: 1,
            z: 0,
            exits: [],
            features: [],
            flags: ["no_fight"]
          }
        ])

      cells =
        rooms
        |> Enum.map(fn room ->
          cell = %Kantele.MiniMap.Cell{
            id: room.id,
            name: room.name,
            x: room.x,
            y: room.y,
            z: room.z,
            map_color: "green",
            connections: %Kantele.MiniMap.Connections{}
          }

          {{room.x, room.y}, cell}
        end)
        |> Enum.into(%{})

      ZoneCache.cache(%Kantele.World.Zone{
        id: zone_id,
        name: "测试流溪",
        mini_map: %Kantele.MiniMap{id: zone_id, cells: cells},
        rooms: rooms
      })

      start_supervised!(
        {Kalevala.World.CharacterSupervisor,
         [name: Kalevala.World.CharacterSupervisor.global_name(zone_id)]}
      )

      # 合法落点的房间必须真实运行，否则 SpawnController 入场失败会导致 Foreman 消亡
      @allowed_rooms
      |> Enum.with_index()
      |> Enum.each(fn {key, idx} ->
        room = Enum.find(rooms, &(&1.key == key))

        options = %{
          room: room,
          item_instances: [],
          config: %{
            supervisor_name: Kalevala.World.CharacterSupervisor.global_name(zone_id),
            callback_module: Kantele.World.Room
          },
          genserver_options: [name: Kalevala.World.Room.global_name(room)]
        }

        start_supervised({Kalevala.World.Room, options}, id: :"mirror_room_#{idx}")
      end)

      # 注册本 zone 的 task 物品（owner/owner_id 供上交匹配）
      register_task_items(zone_id, [
        {"t1", "张三", "zhang"},
        {"t2", "李四", "li"}
      ])

      start_supervised!(
        {MirrorDaemon,
         [name: daemon, zone_id: zone_id, total_tasks: 2, round_interval: 3_600_000]}
      )

      on_exit(fn ->
        # 收掉本 zone 监督树下的任务载体（全球名未注册时静默跳过）
        case :global.whereis_name({Kalevala.World.CharacterSupervisor, zone_id}) do
          nil -> :ok
          :undefined -> :ok
          sup -> sup |> DynamicSupervisor.which_children() |> Enum.each(fn {_, p, _, _} -> if is_pid(p), do: Process.exit(p, :shutdown) end)
        end
      end)

      %{daemon: daemon, zone_id: zone_id}
    end

    test "start_round 生成 TaskCarrier：存活、入监督树、携带 task 物品、落地合法房间", %{
      daemon: daemon,
      zone_id: zone_id
    } do
      assert {:ok, state} = GenServer.call(daemon, :start_round)

      assert map_size(state.tasks) == 2
      assert state.round_active

      allowed = Enum.map(@allowed_rooms, &"#{zone_id}:#{&1}")
      supervisor = :global.whereis_name({Kalevala.World.CharacterSupervisor, zone_id})

      children =
        supervisor
        |> DynamicSupervisor.which_children()
        |> Enum.map(fn {_, p, _, _} -> p end)

      Enum.each(state.tasks, fn {name, info} ->
        assert info.alive
        assert is_pid(info.pid)
        assert Process.alive?(info.pid)
        assert info.pid in children
        assert info.room_id in allowed
        assert info.owner_id in ["zhang", "li"]

        foreman = :sys.get_state(info.pid)
        expected_item_id = "#{zone_id}:task/#{name}"
        assert [%Kalevala.World.Item.Instance{item_id: ^expected_item_id}] =
                 foreman.character.inventory
      end)

      assert %{round_active: true, tasks_alive: 2} = GenServer.call(daemon, :status)

      # SpawnController 异步入场：等一会儿角色应订阅到所属房间频道
      Process.sleep(200)

      Enum.each(state.tasks, fn {_name, info} ->
        room_pids =
          Kantele.Communication.subscribers("rooms:#{info.room_id}")
          |> Enum.map(fn {_channel_name, p, _options} -> p end)

        assert info.pid in room_pids
      end)
    end

    test "on_task_completed 上报：全部上交后计数到齐、收轮", %{daemon: daemon} do
      assert {:ok, state} = GenServer.call(daemon, :start_round)

      for name <- Map.keys(state.tasks) do
        MirrorDaemon.on_task_completed(daemon, name, %{id: "player-1", name: "张三"})
      end

      wait_until(fn ->
        %{all_completed: true, total_completed: 2, round_active: false} = GenServer.call(daemon, :status)
      end)
    end

    test "没有可用房间时整轮跳过（全部 no_fight）" do
      all_no_fight_zone_id = "tmirnf-#{System.unique_integer([:positive])}"

      ZoneCache.cache(%Kantele.World.Zone{
        id: all_no_fight_zone_id,
        name: "禁地",
        mini_map: %Kantele.MiniMap{id: all_no_fight_zone_id, cells: %{}},
        rooms: [
          %Kantele.World.Room{
            id: "#{all_no_fight_zone_id}:heian",
            key: "heian",
            zone_id: all_no_fight_zone_id,
            name: "黑道",
            x: 1,
            y: 1,
            z: 0,
            exits: [],
            features: [],
            flags: ["no_fight"]
          }
        ]
      })

      register_task_items(all_no_fight_zone_id, [{"t3", "王五", "wang"}])

      no_room_daemon = :"mirror_daemon_nf_#{System.unique_integer([:positive])}"
      start_supervised!({MirrorDaemon, [name: no_room_daemon, zone_id: all_no_fight_zone_id, total_tasks: 30, round_interval: 3_600_000]})

      assert {:ok, state} = GenServer.call(no_room_daemon, :start_round)
      assert state.tasks == %{}
      assert state.round_active
      assert %{tasks_alive: 0} = GenServer.call(no_room_daemon, :status)
    end

    test "无监督树/无 ZoneCache 时降级：不生成载体也不崩溃" do
      ghost_zone = "tmirghost-#{System.unique_integer([:positive])}"
      register_task_items(ghost_zone, [{"g1", "赵六", "zhao"}])

      ghost_daemon = :"mirror_daemon_ghost_#{System.unique_integer([:positive])}"
      start_supervised!({MirrorDaemon, [name: ghost_daemon, zone_id: ghost_zone, total_tasks: 30, round_interval: 3_600_000]})

      assert {:ok, state} = GenServer.call(ghost_daemon, :start_round)
      assert state.tasks == %{}
      assert %{tasks_alive: 0} = GenServer.call(ghost_daemon, :status)
    end
  end

  # ---- helpers ----

  defp register_task_items(zone_id, entries) do
    for {name, owner, owner_id} <- entries do
      id = "#{zone_id}:task/#{name}"

      Items.put(id, %Kalevala.World.Item{
        id: id,
        name: "任务令牌#{name}",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{owner: owner, owner_id: owner_id}
      })
    end

    :ok
  end

defp wait_until(fun, tries \\ 100) do
  if tries == 0 do
    flunk("wait_until timed out")
  else
    try do
      if fun.() do
        :ok
      else
        Process.sleep(20)
        wait_until(fun, tries - 1)
      end
    rescue
      _e -> Process.sleep(20); wait_until(fun, tries - 1)
    end
  end
end
end
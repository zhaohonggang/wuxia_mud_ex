defmodule Kantele.World.MirrorZixuSpawnTest do
  use ExUnit.Case, async: false

  alias Kantele.World.MirrorDaemon.Zixu

  @room_name "子虚观"

  setup do
    # 测试环境不加载世界（kickoff=false），按 Q5-T3 真实 wiring 自建基础设施。
    # zone/room/监督器用每测试唯一 id，避免与套件中其他（真实 liuxi 或并发 async）
    # 进程抢占全局命名。start_supervised 在测试结束时回收。
    zone_id = "tzixu-#{System.unique_integer([:positive])}"
    room_id = "#{zone_id}:zixu_guan"

    cell = %Kantele.MiniMap.Cell{
      id: room_id,
      name: @room_name,
      x: -1,
      y: 2,
      z: 0,
      map_color: "cyan",
      connections: %Kantele.MiniMap.Connections{}
    }

    Kantele.World.ZoneCache.cache(%Kantele.World.Zone{
      id: zone_id,
      name: "流溪",
      mini_map: %Kantele.MiniMap{id: zone_id, cells: %{{-1, 2} => cell}}
    })

    start_supervised!(
      {Kalevala.World.CharacterSupervisor,
       [name: Kalevala.World.CharacterSupervisor.global_name(zone_id)]}
    )

    room = %Kantele.World.Room{
      id: room_id,
      key: "zixu_guan",
      zone_id: zone_id,
      name: @room_name,
      description: "子虚道人清修之所，香烟袅袅，仙气缭绕。",
      x: -1,
      y: 2,
      z: 0,
      exits: [],
      features: [],
      flags: ["no_fight"]
    }

    options = %{
      room: room,
      item_instances: [],
      config: %{
        supervisor_name: Kalevala.World.CharacterSupervisor.global_name(zone_id),
        callback_module: Kantele.World.Room
      },
      genserver_options: [name: Kalevala.World.Room.global_name(room)]
    }

    {:ok, room_pid} = start_supervised({Kalevala.World.Room, options})

    on_exit(fn ->
      # 收掉子虚道人进程（全球名未注册时静默跳过），避免跨测试残留
      case :global.whereis_name({Kalevala.World.CharacterSupervisor, zone_id}) do
        nil ->
          :ok

        :undefined ->
          :ok

        sup ->
          sup
          |> DynamicSupervisor.which_children()
          |> Enum.each(fn {_, pid, _, _} -> if is_pid(pid), do: Process.exit(pid, :shutdown) end)
      end
    end)

    %{room_pid: room_pid, zone_id: zone_id, room_id: room_id}
  end

  test "build_zixu 数据完备（kind 标记、问询表、驻守房间）" do
    zixu = Zixu.build_zixu()

    assert zixu.id == "zixu_daoren"
    assert zixu.name == "子虚道人"
    assert zixu.room_id == "liuxi:zixu_guan"
    assert zixu.meta.kind == "zixu"
    assert zixu.meta.zone_id == "liuxi"

    assert zixu.meta.inquiries["mirror"] == :ask_mirror
    assert zixu.meta.inquiries["宝镜"] == :ask_mirror
    assert zixu.meta.inquiries["乾坤宝镜"] == :ask_mirror
    assert zixu.meta.inquiries["心魔幻境"] == :ask_maze

    assert zixu.meta.vitals.max_qi == 50_000
    assert zixu.meta.stats.str == 50
  end

  test "start_zixu(zone_id) 在世界就绪时启动真实 NPC 进程（存活、挂监督树、入住房间）", %{
    zone_id: zone_id,
    room_id: room_id
  } do
    assert {:ok, pid} = Zixu.start_zixu(zone_id)
    assert Process.alive?(pid)

    supervisor = :global.whereis_name({Kalevala.World.CharacterSupervisor, zone_id})
    assert is_pid(supervisor)

    children_pids =
      supervisor
      |> DynamicSupervisor.which_children()
      |> Enum.map(fn {_, child_pid, _, _} -> child_pid end)

    assert pid in children_pids

    # 等 SpawnController 完成入场（move to room + subscribe）
    Process.sleep(200)

    room_pids =
      Kantele.Communication.subscribers("rooms:#{room_id}")
      |> Enum.map(fn {_channel_name, p, _options} -> p end)

    assert pid in room_pids
  end

  test "start_zixu 重复调用在监督树中叠加新进程（reload 重建语义由 reset_characters 负责）", %{
    zone_id: zone_id
  } do
    assert {:ok, pid1} = Zixu.start_zixu(zone_id)
    assert {:ok, pid2} = Zixu.start_zixu(zone_id)
    assert Process.alive?(pid1)
    assert Process.alive?(pid2)
    assert pid1 != pid2
  end
end
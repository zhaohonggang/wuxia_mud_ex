defmodule Kantele.World.Story.ChallengerTest do
  use ExUnit.Case, async: false

  alias Kantele.World.Story.Challenger

  @server :test_challenger_server

  setup do
    start_supervised!({Challenger, name: @server})

    on_exit(fn ->
      # 收掉摆擂 NPC 进程与登记，房间由 start_supervised 自动回收
      case Process.whereis(@server) do
        nil -> :ok
        _pid ->
          case Challenger.current(nil, @server) do
            nil -> :ok
            %{pid: npc_pid} -> if is_pid(npc_pid) and Process.alive?(npc_pid), do: Process.exit(npc_pid, :shutdown)
          end

          Challenger.despawn(@server)
      end
    end)

    :ok
  end

  test "spawn 在真实房间摆擂并登记（NPC 进程存活、可按房间过滤）" do
    room_id = start_test_room()

    assert {:ok, challenger} = Challenger.spawn(@server, room_id)
    assert challenger.id =~ ~r/^challenge-/
    assert challenger.name == "神秘挑战者"
    assert challenger.accepted_by == nil
    assert challenger.room_id == room_id
    assert Process.alive?(challenger.pid)

    assert Challenger.current(room_id, @server).id == challenger.id
    assert Challenger.current("nope-room-xyz", @server) == nil
  end

  test "spawn 房间不存在时优雅失败" do
    assert {:error, {:room_not_running, "nope-room-xyz"}} =
             Challenger.spawn(@server, "nope-room-xyz")

    assert Challenger.current(nil, @server) == nil
  end

  test "accept 登记应战者并更新状态" do
    room_id = start_test_room()
    assert {:ok, challenger} = Challenger.spawn(@server, room_id)

    player = %{id: "p-zhang", name: "张三"}
    assert :ok = Challenger.accept(@server, player)
    assert Challenger.current(room_id, @server).accepted_by == "p-zhang"
    assert Challenger.current(room_id, @server).id == challenger.id
  end

  test "on_died 命中登记则收摊，不命中则保持" do
    room_id = start_test_room()
    assert {:ok, challenger} = Challenger.spawn(@server, room_id)

    # 无关 id：保持登记
    Challenger.on_died(@server, "nope-id", %{id: "p-other", name: "路人"})
    :timer.sleep(20)
    assert Challenger.current(room_id, @server).id == challenger.id

    # 命中 id：收摊（广播由下次 spawn 的 announce 覆盖，无需断言精确文案）
    Challenger.on_died(@server, challenger.id, %{id: "p-zhang", name: "张三"})
    :timer.sleep(20)
    assert Challenger.current(room_id, @server) == nil
  end

  test "despawn 收摊" do
    room_id = start_test_room()
    assert {:ok, _challenger} = Challenger.spawn(@server, room_id)
    assert Challenger.despawn(@server) == true
    assert Challenger.current(room_id, @server) == nil
  end

  # ---- 测试房间 ----

  # 测试世界未加载（test env kickoff=false），自建一个独立 zone：
  # 本 zone 角色监督器 + 房间都用唯一名字，测试结束由 start_supervised 回收，
  # 不污染真实 liuxi 世界。
  defp start_test_room() do
    zone_id = "tzone-#{System.unique_integer([:positive])}"
    room_id = "troom-#{System.unique_integer([:positive])}"

    # room/look 会画小地图，需要缓存一份 test zone（空图即可）
    Kantele.World.ZoneCache.cache(%Kantele.World.Zone{
      id: zone_id,
      name: "创世山",
      mini_map: %Kantele.MiniMap{id: zone_id, cells: %{}}
    })

    start_supervised!(
      {Kalevala.World.CharacterSupervisor,
       [name: Kalevala.World.CharacterSupervisor.global_name(zone_id)]}
    )

    room = %Kantele.World.Room{
      id: room_id,
      key: "storytest",
      zone_id: zone_id,
      name: "试炼擂台",
      description: "一座临时搭建的擂台，专供接引初入江湖的豪杰。",
      exits: [],
      features: [],
      flags: []
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

    {:ok, _pid} = start_supervised({Kalevala.World.Room, options})
    room_id
  end
end
defmodule Kantele.World.IntegrationConvertSpawnTest do
  @moduledoc """
  灵蛇杖 `convert` → spawn 灵蛇 NPC 的 Docker 集成测试。

  端到端验证：守门通过后，`ConvertBian.run/2` 调用
  `Kalevala.World.start_character/2` 启动真实 NPC 进程，NPC 经
  `SpawnController` 入场并订阅房间频道，法杖从玩家背包移除。

  需真实房间 GenServer + CharacterSupervisor，故不能放进纯单测。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.Stats
  alias Kalevala.Character.Conn
  alias Kalevala.World.CharacterSupervisor
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.World.ItemActions.ConvertBian
  alias Kantele.World.Room
  alias Kantele.World.Zone
  alias Kantele.MiniMap

  @room_name "小院"

  setup do
    zone_id = "tbaituo-#{System.unique_integer([:positive])}"
    room_id = "#{zone_id}:xiaoyuan"

    cell = %MiniMap.Cell{
      id: room_id,
      name: @room_name,
      x: 0,
      y: 0,
      z: 0,
      map_color: "green",
      connections: %MiniMap.Connections{}
    }

    Kantele.World.ZoneCache.cache(%Zone{
      id: zone_id,
      name: "白驼山",
      mini_map: %MiniMap{id: zone_id, cells: %{{0, 0} => cell}}
    })

    start_supervised!(
      {CharacterSupervisor, [name: CharacterSupervisor.global_name(zone_id)]}
    )

    room = %Room{
      id: room_id,
      key: "xiaoyuan",
      zone_id: zone_id,
      name: @room_name,
      description: "测试房间",
      x: 0,
      y: 0,
      z: 0,
      exits: [],
      features: [],
      flags: []
    }

    options = %{
      room: room,
      item_instances: [],
      config: %{
        supervisor_name: CharacterSupervisor.global_name(zone_id),
        callback_module: Kantele.World.Room
      },
      genserver_options: [name: Kalevala.World.Room.global_name(room_id)]
    }

    {:ok, _room_pid} = start_supervised({Kalevala.World.Room, options})

    staff = %Item{
      id: "baituo:lingshezhang",
      name: "灵蛇杖",
      meta: %{
        actions: [%{verb: "convert", handler: "convert_lingshe"}],
        damage: 180,
        skill_type: "staff"
      }
    }

    instance = %Instance{id: "inst-1", item_id: staff.id, item: staff}

    character = %Kalevala.Character{
      name: "欧阳克",
      room_id: room_id,
      meta: %{
        family: %{name: "欧阳世家"},
        stats: %Stats{skills: %{"training" => 200}},
        vitals: %{jing: 200, max_jing: 200, base_jing: 200}
      },
      inventory: [instance]
    }

    conn = %Conn{
      character: character,
      private: %Conn.Private{
        room: %Room{id: room_id},
        channel_changes: []
      },
      output: []
    }

    params = %{
      verb: "convert",
      trailing: "",
      room_id: room_id,
      item: staff,
      instance: instance,
      handler: "convert_lingshe"
    }

    on_exit(fn ->
      case :global.whereis_name({CharacterSupervisor, zone_id}) do
        nil -> :ok
        :undefined -> :ok
        sup ->
          sup
          |> DynamicSupervisor.which_children()
          |> Enum.each(fn {_, pid, _, _} -> if is_pid(pid), do: Process.exit(pid, :shutdown) end)
      end
    end)

    %{conn: conn, params: params, room_id: room_id}
  end

  test "convert_lingshe 守门通过 → spawn 灵蛇 NPC 入住房间 + 移除法杖 + 送达文案",
    %{conn: conn, params: params, room_id: room_id} do

    result = ConvertBian.run(conn, params)

    refute result == :not_handled, "守门应通过，返回 conn"

    # 等 SpawnController 异步完成入场（move to room + subscribe rooms:<id>）
    Process.sleep(400)

    room_pids =
      Kantele.Communication.subscribers("rooms:#{room_id}")
      |> Enum.map(fn {_channel_name, p, _options} -> p end)

    # 房间内应有新进程订阅（即 spawn 出来的灵蛇 NPC foreman）
    assert length(room_pids) > 0
    assert Enum.all?(room_pids, &is_pid/1)
    assert Enum.any?(room_pids, &Process.alive?/1)

    # 法杖应从背包移除（destruct 等价）
    updated = result.private.update_character
    refute updated == nil
    assert not Enum.any?(updated.inventory, fn inst -> inst.item_id == "baituo:lingshezhang" end)

    # 玩家应收到成功文案
    out_text = result.output |> Enum.map(& &1.data) |> Enum.join()
    assert String.contains?(out_text, "灵蛇")
  end
end

defmodule Kantele.Character.SleepRoomFlagsTest.FakeRoom do
  @moduledoc """
  只满足 `Kantele.World.Room.snapshot/1` 的最小房间：`state.data` 是
  `%Kantele.World.Room{}`（带 flags），`state.private` 提供 characters/item_instances。

  与 `FillCommandTest.FakeRoom` 同构 —— 这里专门用来验证 P3 的
  `sleep_room` / `no_sleep_room` 从**房间 flags** 一路走到 `sleep` 命令的判定。
  """

  use GenServer

  def start_link({room_id, flags}) do
    GenServer.start_link(__MODULE__, {room_id, flags},
      name: {:global, {Kalevala.World.Room, room_id}}
    )
  end

  @impl true
  def init({room_id, flags}) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id, flags: flags},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.Character.SleepRoomFlagsTest do
  @moduledoc """
  P3 DoD：`sleep_room` / `no_sleep_room` 的**全链**验证。

  `sleep_command_test.exs` 里的用例是把 `room` 直接塞进 `conn.private` 的单元测试，
  覆盖不到 `Room.snapshot/1` 把 `flags` 翻成 `attrs` 的那一跳。这里起一个真房间
  （只实现 snapshot 需要的两个字段），让命令自己走 `snapshot/1`，从而锁定：

      flags: ["sleep_room"] -> attrs["sleep_room"] == true -> 可睡
      flags: ["no_sleep_room"] -> attrs["no_sleep_room"] == true -> 拒绝（优先于 sleep_room）
      flags: [] -> 两个 attrs 都 false -> 拒绝
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SleepCommand
  alias Kantele.Character.SleepRoomFlagsTest.FakeRoom
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @inn "test:sleep_flags_inn"
  @tomb "test:sleep_flags_tomb"
  @street "test:sleep_flags_street"

  setup_all do
    {:ok, inn} = FakeRoom.start_link({@inn, ["sleep_room"]})
    {:ok, tomb} = FakeRoom.start_link({@tomb, ["sleep_room", "no_sleep_room"]})
    {:ok, street} = FakeRoom.start_link({@street, []})

    on_exit(fn ->
      for pid <- [inn, tomb, street], Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  defp player(room_id) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 0,
      score: 0,
      potential: 0,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-sleep-flags",
      name: "张三",
      pid: self(),
      room_id: room_id,
      inventory: [],
      attributes: %{"qi" => 5000, "jing" => 2000},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "snapshot flags -> sleep 判定" do
    test "snapshot 把 flags 翻成布尔 attrs" do
      attrs = Kantele.World.Room.snapshot(@inn).attrs

      assert attrs["sleep_room"] == true
      assert attrs["no_sleep_room"] == false
    end

    test "sleep_room 房间：走 snapshot 也能睡" do
      # 注意：不往 conn.private 里塞 room，强制命令自己调 snapshot/1
      conn = SleepCommand.run(build_conn(player(@inn)), %{})

      assert output_text(conn) =~ "梦乡"

      character = Kalevala.Character.Conn.character(conn)
      assert character.meta.temp["sleeped"] == true
    end

    test "no_sleep_room 优先于 sleep_room：拒绝" do
      conn = SleepCommand.run(build_conn(player(@tomb)), %{})

      assert output_text(conn) =~ "这里不是你能睡的地方"

      character = Kalevala.Character.Conn.character(conn)
      assert character.meta.temp["sleeped"] == nil
    end

    test "无 flags 的普通房间：拒绝" do
      conn = SleepCommand.run(build_conn(player(@street)), %{})

      assert output_text(conn) =~ "这里不是你能睡的地方"
    end

    test "房间不存在（snapshot 回退分支）：拒绝且不崩" do
      conn = SleepCommand.run(build_conn(player("test:no_such_room")), %{})

      assert output_text(conn) =~ "这里不是你能睡的地方"
    end
  end
end

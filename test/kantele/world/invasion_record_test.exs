defmodule Kantele.World.InvasionRecordTest do
  @moduledoc """
  A-5-c C1：Invasion 守护进程 record 查询与波次级 born_time。

  对应 LPC `adm/daemons/invasion/invasiond.c:25`（record/born_time 每波统一置一次）
  与 `kangxi.c` / `yuqian1.c` ask_reward 的 `INVASIOND->query("record")` 门。
  """

  use ExUnit.Case, async: false

  alias Kantele.World.Invasion

  test "record/1 在进程不存在时安全返回 exists:false，不崩溃" do
    assert %{
             exists: false,
             wave_number: 0,
             wave_active: false,
             born_time: nil,
             total_killed: 0,
             all_killed: false
           } = Invasion.record(:"no_such_invasion_#{System.unique_integer([:positive])}")
  end

  test "init_state 未开波时 born_time=nil，status 不含有效 record" do
    state = Invasion.init_state()

    assert Map.get(state, :born_time) == nil
    assert Invasion.status(state).born_time == nil
    assert Invasion.status(state).all_killed == false
  end

  test "start_wave 置波次级 born_time（非每个 invader 各自取值）" do
    state = Invasion.init_state()

    assert {:ok, new_state} = Invasion.start_wave(state, [])
    assert is_integer(Map.get(new_state, :born_time))
    assert Map.get(new_state, :born_time) > 0
    assert new_state.wave_active == true
    assert Invasion.status(new_state).born_time == Map.get(new_state, :born_time)
  end

  test "具名 GenServer 的 record 查询对齐 LPC INVASIOND record 字段" do
    name = :"invasion_record_test_#{System.unique_integer([:positive])}"

    {:ok, pid} =
      Invasion.start_link(
        name: name,
        start_delay: 3_600_000,
        wave_interval: 3_600_000
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end)

    assert %{
             exists: false,
             wave_number: 0,
             wave_active: false,
             born_time: nil,
             total_killed: 0,
             all_killed: false
           } = Invasion.record(name)

    # 触发开波后 record.exists 应变 true 且 born_time 与 status 一致
    assert {:ok, _wave} = GenServer.call(name, :start_wave)
    record = Invasion.record(name)

    assert record.exists == true
    assert is_integer(record.born_time)
    assert record.born_time == GenServer.call(name, :status).born_time
  end
end

defmodule Kantele.World.RoomWaterFlagBackfillTest do
  @moduledoc """
  验证 `scripts/backfill_room_water_flag.py` 把 LPC
  `set("resource/water", 1)` 正确写成了房间 flag `"water"`。

  为什么这条测试重要：`fill_command.ex`（`cmds/std/fill.c` 的移植）的前置条件是
  `Room.snapshot/1` 给出的 `attrs["water"]`，而 snapshot 的取值就是
  `"water" in flags`。转换器从不输出房间 `flags`，所以这批数据若丢了，
  灌水功能会在**任何**房间都回「这里没有地方可以装水。」—— 而且不会报错，
  属于「静默失效」型回归，必须靠数据断言锁住。

  覆盖三层：
    1. 数量与形状（47 房、flags 是字符串列表）；
    2. 抽样语义（厨房/茶馆/井/泉/湖/水帘洞 —— LPC 里给水的地方）；
    3. **并入已有 flags 块的 2 个房间**必须既保住原 flag 又拿到 `water`
       （`room:chufang` 的 `no_sleep_room`、`shaolin:houdian` 的 `startroom`）。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  @moduletag :world_data

  # LPC 侧 48 处 `set("resource/water", 1)`，其中 minimal_world 无 UCL（out of scope）
  # → 应落 47 房。
  @expected_count 47

  setup_all do
    %{world: Loader.load()}
  end

  defp room(world, id), do: Enum.find(world.rooms, &(&1.id == id))

  test "回填数量与形状", %{world: world} do
    water_rooms = Enum.filter(world.rooms, fn r -> "water" in (r.flags || []) end)

    assert length(water_rooms) == @expected_count,
           "期望 #{@expected_count} 个 water 房间，实际 #{length(water_rooms)}"

    # snapshot/1 做的是 `"water" in flags`，所以 flags 必须是字符串列表
    assert Enum.all?(water_rooms, fn r -> Enum.all?(r.flags, &is_binary/1) end)
  end

  test "抽样：厨房 / 茶馆 / 井 / 泉 / 湖 / 水帘洞 都有 water", %{world: world} do
    for id <- ~w(
      shaolin:chufang
      hengyang:chaguan
      huanggong:inwell
      lingzhou:qingxinquan
      shenfeng:lake1
      hangzhou:shuiledong
      lingxiao:water
      qingcheng:yuanyangjing
    ) do
      r = room(world, id)
      assert r, "未找到房间 #{id}"
      assert "water" in r.flags, "#{id} 缺少 water flag"
    end
  end

  test "并入已有 flags 块：原 flag 不被覆盖", %{world: world} do
    # room:chufang 原本只有 no_sleep_room（B1 批），本批并入 water
    chufang = room(world, "room:chufang")
    assert chufang, "未找到 room:chufang"
    assert "no_sleep_room" in chufang.flags
    assert "water" in chufang.flags

    # shaolin:houdian 原本只有 startroom，本批并入 water
    houdian = room(world, "shaolin:houdian")
    assert houdian, "未找到 shaolin:houdian"
    assert "startroom" in houdian.flags
    assert "water" in houdian.flags
  end

  test "非水源房间不受影响", %{world: world} do
    for id <- ~w(city:wudao1 shaolin:guangchang1) do
      r = room(world, id)
      assert r, "未找到房间 #{id}"
      refute "water" in r.flags, "#{id} 不应有 water flag"
    end
  end

  test "回填幂等：同房不重复出现 water", %{world: world} do
    for r <- world.rooms, "water" in (r.flags || []) do
      assert Enum.count(r.flags, &(&1 == "water")) == 1, "#{r.id} 重复 water"
    end
  end
end

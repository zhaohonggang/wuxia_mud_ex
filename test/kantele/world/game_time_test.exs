defmodule Kantele.World.GameTimeTest do
  use ExUnit.Case, async: true

  alias Kantele.World.GameTime
  alias Kantele.World.GameTime.Calendar

  @real_epoch 1_767_225_600

  test "倍率：现实 1 秒 = 游戏 12 秒（现实 5s = 游戏 1min）" do
    assert Calendar.game_seconds(@real_epoch + 1) - Calendar.game_seconds(@real_epoch) == 12
    assert Calendar.rate() == 12
  end

  test "锚点：真实 2026-01-01 00:00 UTC 对应游戏 1996-01-01（UTC+8）" do
    dt = Calendar.datetime(@real_epoch)

    assert dt.year == 1996
    assert dt.month == 1
    assert dt.day == 1
    assert dt.hour == 8
  end

  test "跨天：真实一天过去 → 游戏推进 12 天" do
    lt0 = Calendar.localtime(@real_epoch)
    lt1 = Calendar.localtime(@real_epoch + 86_400)

    assert lt1.day - lt0.day == 12
    assert lt1.month == 1
  end

  test "季节边界：3|6|9|12 月起止" do
    assert Calendar.season(1) == :winter
    assert Calendar.season(2) == :winter
    assert Calendar.season(3) == :spring
    assert Calendar.season(5) == :spring
    assert Calendar.season(6) == :summer
    assert Calendar.season(8) == :summer
    assert Calendar.season(9) == :autumn
    assert Calendar.season(11) == :autumn
    assert Calendar.season(12) == :winter
  end

  test "localtime 字段齐备且 hour 随真实时间推进" do
    lt = Calendar.localtime(@real_epoch)

    assert %{year: 1996, month: 1, day: 1, hour: 8, minute: 0, second: 0} = lt

    # 真实 1 分钟 = 游戏 12 分钟
    lt2 = Calendar.localtime(@real_epoch + 60)
    assert lt2.minute == 12
  end

  describe "GenServer" do
    test "匿名实例：now 注入返回固定游戏钟" do
      {:ok, server} = GameTime.start_link(name: :anonymous, now: @real_epoch)

      assert %{year: 1996, month: 1, day: 1, hour: 8} = GameTime.game_localtime(server)
      assert GameTime.season(server) == :winter
      assert GameTime.hour(server) == 8
    end

    test "现实 300 秒 = 游戏 1 小时，小时进位" do
      {:ok, server} = GameTime.start_link(name: :anonymous, now: @real_epoch + 300)
      assert GameTime.hour(server) == 9
    end
  end
end
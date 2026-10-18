defmodule Kantele.World.NpcActions.CountersTest do
  use ExUnit.Case, async: false

  alias Kantele.World.NpcActions.Counters

  setup do
    Counters.reset(:all)
    :ok
  end

  test "limit/1 首次访问按 random(15) 初始化，返回 0..14" do
    total = Counters.limit("test:room_a")
    assert is_integer(total)
    assert total >= 0 and total <= 14
  end

  test "limit/1 同一房间返回值稳定（只初始化一次）" do
    first = Counters.limit("test:room_b")
    assert Counters.limit("test:room_b") == first
  end

  test "record/2 累加计数，count/2 读取" do
    Counters.limit("test:room_c")
    assert Counters.count("test:room_c", "blade") == 0
    assert Counters.record("test:room_c", "blade") == 1
    assert Counters.record("test:room_c", "blade") == 2
    assert Counters.count("test:room_c", "blade") == 2
  end

  test "不同 arg 计数互不影响" do
    Counters.limit("test:room_d")
    Counters.record("test:room_d", "blade")
    Counters.record("test:room_d", "blade")
    Counters.record("test:room_d", "body")
    assert Counters.count("test:room_d", "blade") == 2
    assert Counters.count("test:room_d", "body") == 1
  end

  test "put_total/2 可确定性地设定上限" do
    Counters.put_total("test:room_e", 3)
    assert Counters.limit("test:room_e") == 3
  end

  test "reset/1 清空指定房间，reset/0 清空全部" do
    Counters.put_total("test:room_f", 5)
    Counters.record("test:room_f", "blade")
    Counters.reset("test:room_f")
    # 重新初始化后 count 归零（total 重新随机）
    assert Counters.count("test:room_f", "blade") == 0
  end
end

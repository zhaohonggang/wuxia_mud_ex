defmodule Kantele.Character.PlayerMetaTempTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.PlayerMeta

  test "get_temp 缺省返回 nil" do
    assert PlayerMeta.get_temp(%PlayerMeta{}, "cooldown") == nil
  end

  test "get_temp 支持默认值" do
    assert PlayerMeta.get_temp(%PlayerMeta{}, "attempt", 0) == 0
  end

  test "put_temp 写入后 get_temp 可取回" do
    meta = %PlayerMeta{}
    meta = PlayerMeta.put_temp(meta, "last_zhenjiu", 123)
    assert PlayerMeta.get_temp(meta, "last_zhenjiu") == 123
  end

  test "put_temp 覆盖旧值" do
    meta = %PlayerMeta{}

    assert meta
           |> PlayerMeta.put_temp(:k, 1)
           |> PlayerMeta.put_temp(:k, 2)
           |> PlayerMeta.get_temp(:k) == 2
  end

  test "add_temp 从 0 起步累加" do
    meta = %PlayerMeta{}
    meta = PlayerMeta.add_temp(meta, "attempt_hit", 1)
    meta = PlayerMeta.add_temp(meta, "attempt_hit", 1)
    assert PlayerMeta.get_temp(meta, "attempt_hit") == 2
  end

  test "add_temp 缺省自增 1" do
    meta = %PlayerMeta{}
    meta = PlayerMeta.add_temp(meta, "count")
    assert PlayerMeta.get_temp(meta, "count") == 1
  end

  test "delete_temp 删除后返回 nil" do
    meta = %PlayerMeta{} |> PlayerMeta.put_temp("rent_paid", 5)
    meta = PlayerMeta.delete_temp(meta, "rent_paid")
    assert PlayerMeta.get_temp(meta, "rent_paid") == nil
  end

  test "temp 会随 trim 进入房间视图（valid_leave 需要读 query_temp）" do
    # 契约变更（原先断言 temp 不进房间视图）：
    #
    # 房间侧要执行 valid_leave 条件，而条件里的 `me->query_temp("rent_paid")`
    # 读的是**移动事件里那份 character** —— 它经过 Conn.private/1(= Meta.trim)。
    # 如果 temp 被裁掉，`!me->query_temp('rent_paid')` 恒为真，玩家会被永久
    # 拦在客栈二楼之外（changan:kezhan 就是这个条件）。
    # 房间侧没有别的方式拿到玩家的会话态（ZoneCache 只有世界数据，没有 rent_paid
    # 这种入店时才产生的临时值），所以 temp 必须留在裁剪结果里。
    # 代价是每个房间侧角色副本多带一个小 map，可接受。
    meta = %PlayerMeta{} |> PlayerMeta.put_temp("combat_time", 99)
    trimmed = Kalevala.Meta.Trim.trim(meta)

    assert Map.has_key?(trimmed, :temp)

    # 注意：trim 后是普通 map（不是 %PlayerMeta{}），所以用 Map.get 读，
    # 运行时也是这么读的（见 Kantele.World.ExitVetoContext.temp_of/1）
    assert Map.get(trimmed.temp, "combat_time") == 99

    # vitals 之外，房间侧要读的字段也都在（见 Kantele.Meta.TrimContractTest）
    Enum.each([:vitals, :stats, :family, :temp, :env], fn key ->
      assert Map.has_key?(trimmed, key), "裁剪后丢了 #{key}"
    end)
  end
end

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
    assert meta |> PlayerMeta.put_temp(:k, 1) |> PlayerMeta.put_temp(:k, 2)
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

  test "temp 不随 trim 进入房间视图" do
    meta = %PlayerMeta{} |> PlayerMeta.put_temp("combat_time", 99)
    trimmed = Kalevala.Meta.Trim.trim(meta)
    assert trimmed == %{vitals: nil}
    assert Map.has_key?(trimmed, :temp) == false
  end
end

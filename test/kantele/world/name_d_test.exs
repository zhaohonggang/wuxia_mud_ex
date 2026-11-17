defmodule Kantele.World.NameDTest do
  use ExUnit.Case, async: false

  alias Kantele.World.NameD

  setup do
    NameD.ensure!()
    :ets.delete_all_objects(NameD.table())
    :ok
  end

  test "map_name then who_is returns the id" do
    NameD.map_name("张三", "player:zhangsan")
    assert NameD.who_is("张三") == "player:zhangsan"
  end

  test "map_name same name different id appends with /" do
    NameD.map_name("张三", "player:zhangsan")
    NameD.map_name("张三", "player:zhangsan2")
    assert NameD.who_is("张三") == "player:zhangsan2/player:zhangsan"
  end

  test "map_name duplicate id is idempotent" do
    NameD.map_name("张三", "player:zhangsan")
    NameD.map_name("张三", "player:zhangsan")
    assert NameD.who_is("张三") == "player:zhangsan"
  end

  test "remove_name removes one id from shared name" do
    NameD.map_name("张三", "player:zhangsan")
    NameD.map_name("张三", "player:zhangsan2")
    NameD.remove_name("张三", "player:zhangsan")
    assert NameD.who_is("张三") == "player:zhangsan2"
  end

  test "remove_name last id deletes the entry" do
    NameD.map_name("张三", "player:zhangsan")
    NameD.remove_name("张三", "player:zhangsan")
    assert NameD.who_is("张三") == nil
  end

  test "remove_name non-existent name is a no-op" do
    assert NameD.remove_name("无此人", "player:nobody") == :ok
  end

  test "invalid_new_name empty string returns error" do
    assert NameD.invalid_new_name("") == "不能使用空名字。"
  end

  test "invalid_new_name family name returns error" do
    assert NameD.invalid_new_name("东方") == "不能使用复姓作为名字。"
  end

  test "invalid_new_name unused name returns nil" do
    assert NameD.invalid_new_name("李四") == nil
  end

  test "invalid_new_name duplicate name returns error" do
    NameD.map_name("王五", "player:wangwu")
    assert NameD.invalid_new_name("王五") == "这个名字和 player:wangwu 的名字重复了。"
  end

  test "change_name success returns ok" do
    assert NameD.change_name("旧名", "player:test", "新名", false) == {:ok, "新名"}
    assert NameD.who_is("新名") == nil # change_name doesn't auto map; caller maps
  end

  test "change_name duplicate returns error" do
    NameD.map_name("已占名", "player:other")
    assert NameD.change_name("旧名", "player:test", "已占名", false) ==
             {:error, "这个名字和 player:other 的名字重复了。"}
  end

  test "read_state returns names after map" do
    NameD.map_name("赵六", "player:zhaoliu")
    state = NameD.read_state()
    assert length(state.names) >= 1
    assert Enum.any?(state.names, &(&1.name == "赵六"))
  end

  test "save! 和 load_state 不崩溃" do
    NameD.map_name("保存测试", "player:save1")
    NameD.map_name("保存测试", "player:save2")

    assert NameD.save!() == :ok

    # 清空 ETS，重新加载
    :ets.delete_all_objects(NameD.table())
    assert NameD.load_state() == %{}
  end

  test "ensure_table is idempotent" do
    assert NameD.ensure!() == :ok
    assert NameD.ensure!() == :ok
  end
end

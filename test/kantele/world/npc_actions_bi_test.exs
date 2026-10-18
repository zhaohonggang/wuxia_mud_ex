defmodule Kantele.World.NpcActions.BiTest do
  use ExUnit.Case, async: true

  alias Kantele.World.NpcActions.DownHandlers

  describe "registered_aliases/0" do
    test "收录麦鲸与元广波两个可倒下处理器" do
      aliases = DownHandlers.registered_aliases()

      assert "mai jing" in aliases
      assert "yuan guangbo" in aliases
    end
  end

  describe "lookup/1" do
    test "麦鲸别名命中 Bi.on_mai_down/2" do
      char = %{meta: %{aliases: ["mai jing", "mai", "jing"]}}

      assert {:ok, {Kantele.World.NpcActions.Bi, :on_mai_down}} =
               DownHandlers.lookup(char)
    end

    test "元广波别名命中 Bi.on_yuan_down/2" do
      char = %{meta: %{aliases: ["yuan guangbo", "yuan", "guangbo"]}}

      assert {:ok, {Kantele.World.NpcActions.Bi, :on_yuan_down}} =
               DownHandlers.lookup(char)
    end

    test "未登记的别名返回 :not_handled" do
      char = %{meta: %{aliases: ["commoner", "npc"]}}

      assert :not_handled = DownHandlers.lookup(char)
    end

  test "无 aliases 的角色返回 :not_handled" do
    char = %{meta: %{}}

    assert :not_handled = DownHandlers.lookup(char)
  end

  test "Bi 实现 NpcAction 行为（run/2）" do
    assert function_exported?(Kantele.World.NpcActions.Bi, :run, 2)
  end

  test "BiEvent 桥接 begin_event/2 与 result/2" do
    assert function_exported?(Kantele.Character.BiEvent, :begin_event, 2)
    assert function_exported?(Kantele.Character.BiEvent, :result, 2)
  end
end
end

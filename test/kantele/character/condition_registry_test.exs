defmodule Kantele.Character.ConditionRegistryTest do
  # 注册表操作 :persistent_term，全局副作用不与 async 测试并发，故 async: false
  use ExUnit.Case, async: false

  alias Kantele.Character.ConditionRegistry

  defmodule DemoCond do
    def update_condition(info), do: {:continue, info}
    def do_effect(state, _cnd, _para), do: {:ok, state}
  end

  describe "静态内建表解析" do
    test "poison 命中已注册 daemon" do
      assert ConditionRegistry.daemon("poison") == {:ok, Kantele.Poison}
    end

    test "未知条件名返回 :error" do
      assert ConditionRegistry.daemon("no-such-cond") == :error
    end
  end

  describe "运行时热增/热删（:persistent_term 增量）" do
    test "register 后 daemon 解析命中、all/1 可见；unregister 还原" do
      name = "demo-#{System.unique_integer([:positive])}"

      on_exit(fn -> ConditionRegistry.unregister(name) end)

      assert ConditionRegistry.daemon(name) == :error
      refute name in ConditionRegistry.all()

      assert ConditionRegistry.register(name, DemoCond) == :ok
      assert ConditionRegistry.daemon(name) == {:ok, DemoCond}
      assert name in ConditionRegistry.all()

      assert ConditionRegistry.unregister(name) == :ok
      assert ConditionRegistry.daemon(name) == :error
      refute name in ConditionRegistry.all()
    end

    test "热增覆盖静态同名（extras 优先），注销后还原静态表" do
      on_exit(fn -> ConditionRegistry.unregister("poison") end)

      assert ConditionRegistry.register("poison", DemoCond) == :ok
      assert ConditionRegistry.daemon("poison") == {:ok, DemoCond}

      assert ConditionRegistry.unregister("poison") == :ok
      assert ConditionRegistry.daemon("poison") == {:ok, Kantele.Poison}
    end
  end
end
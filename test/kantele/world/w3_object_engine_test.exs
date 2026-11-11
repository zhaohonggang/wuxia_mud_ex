defmodule Kantele.World.W3ObjectEngineTest do
  @moduledoc """
  B2 — W3ObjectEngine 核心模块单元测试。

  覆盖：ensure!/ensure_table 幂等、register/lookup/unregister/list/read_state，
  以及受控系统操作 schedule_system（dry-run 默认）与 cancel_system。
  """

  use ExUnit.Case, async: false

  alias Kantele.World.W3ObjectEngine

  defmodule Dummy do
    @moduledoc false
    def run(_args), do: :ran
  end

  setup do
    W3ObjectEngine.ensure!()
    :ok
  end

  describe "ensure! / ensure_table 幂等" do
    test "重复调用不报错且表存在" do
      assert :ok = W3ObjectEngine.ensure!()
      assert :ets.whereis(:w3_objects) != :undefined
      assert :ok = W3ObjectEngine.ensure!()
    end
  end

  describe "register / lookup" do
    test "注册后可查询，字段完整" do
      :ok = W3ObjectEngine.register("obj_alpha", Dummy, %{qi: 100}, "creator")

      entry = W3ObjectEngine.lookup("obj_alpha")
      assert entry.module == Dummy
      assert entry.state == %{qi: 100}
      assert entry.owner == "creator"
      assert is_struct(entry.created_at, DateTime)
      assert entry.parent == nil
    end

    test "owner 缺省为 nil" do
      :ok = W3ObjectEngine.register("obj_beta", Dummy, %{})
      assert W3ObjectEngine.lookup("obj_beta").owner == nil
    end

    test "未注册对象返回 nil" do
      assert W3ObjectEngine.lookup("obj_never") == nil
    end
  end

  describe "unregister" do
    test "删除后查询返回 nil" do
      :ok = W3ObjectEngine.register("obj_gamma", Dummy, %{})
      assert :ok = W3ObjectEngine.unregister("obj_gamma")
      assert W3ObjectEngine.lookup("obj_gamma") == nil
    end

    test "删除不存在的对象返回错误" do
      assert {:error, :not_found} = W3ObjectEngine.unregister("obj_ghost")
    end
  end

  describe "list" do
    test "返回所有已注册对象 ID" do
      :ok = W3ObjectEngine.register("obj_l1", Dummy, %{})
      :ok = W3ObjectEngine.register("obj_l2", Dummy, %{})

      ids = W3ObjectEngine.list()
      assert "obj_l1" in ids
      assert "obj_l2" in ids
      assert length(ids) >= 2
    end
  end

  describe "read_state" do
    test "表缺失时返回缺省状态" do
      # 当前进程已 ensure!，先验证缺省结构存在；缺省对象为空、系统为 nil。
      state = W3ObjectEngine.read_state()
      assert state.objects == %{}
      assert state.system == nil
    end

    test "注册对象后 read_state 反映对象" do
      :ok = W3ObjectEngine.register("obj_rs", Dummy, %{a: 1})
      state = W3ObjectEngine.read_state()
      assert Map.has_key?(state.objects, "obj_rs")
      assert state.objects["obj_rs"].module == Dummy
    end
  end

  describe "schedule_system（受控系统操作）" do
    test "默认 dry-run：记录调度意图但不实际执行" do
      assert {:ok, info} = W3ObjectEngine.schedule_system(:reboot, 0, "巫师")
      assert info.action == :reboot
      assert info.delay_ms == 0
      assert info.actor == "巫师"
      assert info.dry_run == true

      # 调度信息已写入 ETS，可从 read_state 看到。
      assert W3ObjectEngine.read_state().system.action == :reboot
    end

    test "延迟秒数换算为毫秒" do
      {:ok, info} = W3ObjectEngine.schedule_system(:shutdown, 5000, "adm")
      assert info.delay_ms == 5000
    end

    test "cancel_system 清除已调度操作" do
      {:ok, _} = W3ObjectEngine.schedule_system(:reboot, 0, "巫师")
      assert :ok = W3ObjectEngine.cancel_system()
      assert W3ObjectEngine.read_state().system == nil
    end
  end
end

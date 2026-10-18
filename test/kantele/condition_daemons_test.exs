defmodule Kantele.ConditionDaemonsTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.ConditionRegistry
  alias Kantele.Character.Conditions
  alias Kantele.Condition.Attrition
  alias Kantele.Duyan
  alias Kantele.Nishui

  describe "ConditionRegistry" do
    test "nishui / duyan 已注册" do
      assert {:ok, Kantele.Nishui} = ConditionRegistry.daemon("nishui")
      assert {:ok, Kantele.Duyan} = ConditionRegistry.daemon("duyan")
    end

    test "poison 注册未回归，未知条件仍返回 :error" do
      assert {:ok, Kantele.Poison} = ConditionRegistry.daemon("poison")
      assert :error = ConditionRegistry.daemon("no_such_condition")
    end

    test "all/0 含新条件" do
      all = ConditionRegistry.all()
      assert "nishui" in all
      assert "duyan" in all
    end
  end

  describe "Attrition.damage/1 区间（LPC random(n) = 0..n-1）" do
    test "按 neili 分档" do
      for _ <- 1..50, do: assert(Attrition.damage(5000) in 0..49)
      for _ <- 1..50, do: assert(Attrition.damage(3500) in 0..499)
      for _ <- 1..50, do: assert(Attrition.damage(2500) in 0..999)
      for _ <- 1..50, do: assert(Attrition.damage(1500) in 0..1499)
      for _ <- 1..50, do: assert(Attrition.damage(750) in 0..1999)
      for _ <- 1..50, do: assert(Attrition.damage(100) in 0..2999)
    end

    test "边界：正好 4000 走 <50 档，非整数/负数安全" do
      for _ <- 1..30, do: assert(Attrition.damage(4000) in 0..49)
      assert Attrition.damage(nil) == 0
      assert Attrition.damage(-5) in 0..2999
    end
  end

  describe "Attrition.wound/2" do
    test "扣 qi/jing，clamp 到 0" do
      state = %{attributes: %{qi: 100, jing: 30}}

      assert {:ok, %{attributes: %{qi: 60, jing: 0}}} = Attrition.wound(state, 40)
    end
  end

  describe "Nishui" do
    test "daemon/1" do
      assert {:ok, Nishui} = Nishui.daemon("nishui")
      assert :error = Nishui.daemon("duyan")
    end

    test "update_condition：duration >= 1 恒定不递减" do
      info = %{"duration" => 5}
      assert {:continue, ^info} = Nishui.update_condition(info)
    end

    test "update_condition：duration < 1 到期" do
      assert {:expire} = Nishui.update_condition(%{"duration" => 0})
      assert {:expire} = Nishui.update_condition(%{})
    end

    test "do_effect 按 neili 掉 qi/jing" do
      state = %{attributes: %{neili: 0, qi: 5000, jing: 5000}}
      assert {:ok, %{attributes: %{qi: qi, jing: jing}}} = Nishui.do_effect(state, "nishui", nil)
      assert qi < 5000
      assert jing < 5000
      assert (5000 - qi) in 0..2999
    end
  end

  describe "Duyan" do
    test "daemon/1" do
      assert {:ok, Duyan} = Duyan.daemon("duyan")
      assert :error = Duyan.daemon("nishui")
    end

    test "update_condition：每跳减一，< 1 到期" do
      assert {:continue, %{"duration" => 2}} = Duyan.update_condition(%{"duration" => 3})
      assert {:continue, %{"duration" => 1}} = Duyan.update_condition(%{"duration" => 2})
      assert {:expire} = Duyan.update_condition(%{"duration" => 1})
      assert {:expire} = Duyan.update_condition(%{"duration" => 0})
    end
  end

  describe "Conditions 引擎集成（走注册表 daemon）" do
    defp state(conditions, attrs) do
      %{conditions: conditions, cond_applyer: nil, attributes: attrs}
    end

    test "nishui：永续 + 每跳 do_effect 掉血" do
      s = state(%{"nishui" => %{"duration" => 3}}, %{neili: 0, qi: 1000, jing: 1000})
      daemon = &ConditionRegistry.daemon/1

      {s, live?} = Conditions.update_condition(s, daemon)
      assert live?
      assert %{"nishui" => _} = s.conditions

      {:ok, {:ok, s}} = Conditions.affect_by(s, daemon, "nishui", nil)
      assert s.attributes.qi < 1000
      assert s.attributes.jing < 1000
    end

    test "duyan：递减到 0 后从 conditions 移除" do
      s = state(%{"duyan" => %{"duration" => 2}}, %{neili: 0, qi: 1000, jing: 1000})
      daemon = &ConditionRegistry.daemon/1

      {s, live?} = Conditions.update_condition(s, daemon)
      assert live?
      assert s.conditions == %{"duyan" => %{"duration" => 1}}

      {s, live?} = Conditions.update_condition(s, daemon)
      refute live?
      assert s.conditions == nil
    end
  end
end

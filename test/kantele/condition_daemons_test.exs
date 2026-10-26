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

  describe "Drunk（LPC kungfu/condition/drunk.c）" do
    # con=20 + max_neili=1000/50=20 -> limit=(20+20)*2=80
    # => limit/2=40, limit/4=20
    defp drunk_state(duration, overrides \\ %{}) do
      attrs =
        Map.merge(
          %{con: 20, max_neili: 1000, jing: 100, qi: 100, max_jing: 200, max_qi: 200},
          overrides
        )

      %{
        conditions: %{"drunk" => %{"duration" => duration}},
        cond_applyer: nil,
        attributes: attrs
      }
    end

    test "daemon/1 与注册表" do
      assert {:ok, Kantele.Drunk} = Kantele.Drunk.daemon("drunk")
      assert :error = Kantele.Drunk.daemon("poison")
      assert {:ok, Kantele.Drunk} = ConditionRegistry.daemon("drunk")
      assert "drunk" in ConditionRegistry.all()
    end

    test "limit/1 = (con + max_neili/50) * 2（LPC 整数除法）" do
      assert Kantele.Drunk.limit(drunk_state(0)) == 80
      # 内力越深越能喝：max_neili 10000 -> (20 + 200) * 2 = 440
      assert Kantele.Drunk.limit(drunk_state(0, %{max_neili: 10_000})) == 440
      # con 为 nil / 缺失时按 0
      assert Kantele.Drunk.limit(%{attributes: %{}}) == 0
    end

    test "update_condition：每跳减一，< 1 到期" do
      assert {:continue, %{"duration" => 2}} = Kantele.Drunk.update_condition(%{"duration" => 3})
      assert {:expire} = Kantele.Drunk.update_condition(%{"duration" => 1})
      assert {:expire} = Kantele.Drunk.update_condition(%{"duration" => 0})
    end

    test "过量（duration > limit）：标记昏厥 + 醉度归零" do
      s = drunk_state(100)
      {:ok, s} = Kantele.Drunk.do_effect(s, "drunk", nil)

      assert s.condition_unconcious == true
      # 归零后下一跳生命周期即摘除（对应 LPC 的 `return 0`）
      assert s.conditions["drunk"]["duration"] == 0
      assert {:expire} = Kantele.Drunk.update_condition(s.conditions["drunk"])
    end

    test "limit/2 档：扣精 10 + 本人提示 + 房间播报" do
      s = drunk_state(50)
      {:ok, s} = Kantele.Drunk.do_effect(s, "drunk", nil)

      assert s.attributes.jing == 90
      assert s.attributes.qi == 100
      assert {:tell, "你觉得脑中昏昏沉沉，身子轻飘飘地，大概是醉了。\n"} in s.condition_messages

      assert {:vision, "{npc}摇头晃脑地站都站不稳，显然是喝醉了。\n"} in s.condition_messages
      refute Map.get(s, :condition_unconcious)
    end

    test "limit/4 档：回精 10 / 回气 15，且不超上限" do
      s = drunk_state(30)
      {:ok, s} = Kantele.Drunk.do_effect(s, "drunk", nil)

      assert s.attributes.jing == 110
      assert s.attributes.qi == 115
      assert {:tell, "你觉得一阵酒意上冲，眼皮有些沉重了。\n"} in s.condition_messages
      assert {:vision, "{npc}脸上已经略显酒意了。\n"} in s.condition_messages
    end

    test "回气夹到 max（receive_healing 语义）" do
      s = drunk_state(30, %{jing: 195, qi: 199, max_jing: 200, max_qi: 200})
      {:ok, s} = Kantele.Drunk.do_effect(s, "drunk", nil)

      assert s.attributes.jing == 200
      assert s.attributes.qi == 200
    end

    test "低于 limit/4：不发作、无消息" do
      s = drunk_state(10)
      {:ok, s} = Kantele.Drunk.do_effect(s, "drunk", nil)

      assert s.attributes.jing == 100
      assert s.attributes.qi == 100
      refute Map.get(s, :condition_messages)
    end

    test "已倒地（非 living）：只播「依然烂醉如泥」，不昏厥不扣血" do
      s = drunk_state(100, %{qi: 0})
      {:ok, s} = Kantele.Drunk.do_effect(s, "drunk", nil)

      assert {:vision, "{npc}打了个隔，不过依然烂醉如泥。\n"} in s.condition_messages
      refute Map.get(s, :condition_unconcious)
      # 走 !living 分支时不再归零，仍靠生命周期自然递减
      assert s.conditions["drunk"]["duration"] == 100
    end

    test "无 conditions 时安全（不崩、不发作）" do
      assert {:ok, _} = Kantele.Drunk.do_effect(%{conditions: nil, attributes: %{}}, "drunk", nil)
      assert {:ok, _} = Kantele.Drunk.do_effect(%{}, "drunk", nil)
    end

    test "dispel_condition/2：内力够即解酒（need = duration + 50）" do
      # duration=100 -> need=150；force=150 恰好达标
      assert {:ok, msg} =
               Kantele.Drunk.dispel_condition(%{"duration" => 100}, %{force: 150, self?: true})

      assert msg =~ "再没有半点醉酒的感觉"

      # 差一点就失败
      assert {:fail, fail_msg} =
               Kantele.Drunk.dispel_condition(%{"duration" => 100}, %{force: 149, self?: true})

      assert fail_msg =~ "内功火候尚有欠缺"
    end

    test "dispel_condition/2：驱散他人门槛 ×3/2" do
      # self: need = 100 + 50 = 150
      assert {:ok, _} = Kantele.Drunk.dispel_condition(%{"duration" => 100}, %{force: 150})
      # 他人: need = 150 * 3 / 2 = 225
      assert {:fail, msg} =
               Kantele.Drunk.dispel_condition(%{"duration" => 100}, %{
                 force: 224,
                 self?: false,
                 target_name: "李四"
               })

      assert msg =~ "李四"
      assert msg =~ "无法帮助"

      assert {:ok, ok_msg} =
               Kantele.Drunk.dispel_condition(%{"duration" => 100}, %{
                 force: 225,
                 self?: false,
                 target_name: "李四"
               })

      assert ok_msg =~ "李四精神一振"
    end

    test "dispel_condition/2：ctx 缺 force 按 0（一律失败）" do
      assert {:fail, _} = Kantele.Drunk.dispel_condition(%{"duration" => 1}, %{})
    end

    test "condition 协议回调名是 dispel_condition/2（不与 Poison.dispel/2 撞名）" do
      assert function_exported?(Kantele.Drunk, :dispel_condition, 2)
      # Poison 那个 dispel/2 是状态变换式的解毒，语义完全不同
      assert function_exported?(Kantele.Poison, :dispel, 2)
      refute function_exported?(Kantele.Poison, :dispel_condition, 2)
    end
  end
end

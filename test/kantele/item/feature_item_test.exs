defmodule Kantele.Item.FeatureItemTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Item.Effect
  alias Kantele.Item.Liquid
  alias Kantele.Item.Transport
  alias Kantele.Item.Equip
  alias Kantele.Item.Cutable
  alias Kantele.World.Item.Meta

  describe "Effect (food/liquid 效果栈)" do
    test "apply_effect 追加/上限 12/保序" do
      f1 = fn -> :a end
      f2 = fn -> :b end
      f3 = fn _ -> :c end

      eff = Effect.apply_effect(nil, f1)
      assert eff == [f1]
      eff = Effect.apply_effect(eff, f2)
      eff = Effect.apply_effect(eff, f3)
      assert Effect.query_effect(eff) == [f1, f2, f3]
    end

    test "has_effect?/do_effect 执行" do
      agent = _agent(0)

      eff =
        Effect.apply_effect(nil, fn -> Agent.update(agent, &(&1 + 1)) end)

      assert Effect.has_effect?(eff)
      Effect.do_effect(eff, nil)
      assert Agent.get(agent, & &1) == 1
    end

    test "clear_effect 清空" do
      eff = Effect.apply_effect(nil, fn -> :x end)
      assert Effect.clear_effect(eff) == []
    end
  end

  describe "Consume (数据驱动 food/medicine)" do
    test "纯食物：无药效、无效果文案" do
      vitals = Vitals.new()
      stats = Stats.new()

      assert {:ok, effect} =
               Effect.consume(vitals, stats, %Meta{food: 20})

      assert effect.food? == true
      assert effect.medicine? == false
      assert effect.parts == []
      assert effect.vitals == vitals
      assert effect.stats == stats
    end

    test "药效：气血回复钳到上限" do
      vitals = %{Vitals.new() | qi: 100}
      stats = Stats.new()

      assert {:ok, effect} =
               Effect.consume(vitals, stats, %Meta{medicine: %{qi: 50, stats: %{str: 1}}})

      assert effect.vitals.qi == 150
      assert effect.parts == ["气血+50", "臂力+1"]
    end

    test "四维永久+1" do
      vitals = Vitals.new()
      stats = %{Stats.new() | str: 20}

      assert {:ok, effect} =
               Effect.consume(vitals, stats, %Meta{medicine: %{stats: %{str: 1}}})

      assert effect.stats.str == 21
    end

    test "声明的四维全部到软上限 -> reject" do
      vitals = Vitals.new()
      stats = %{Stats.new() | str: 30}

      assert {:reject, reason} =
               Effect.consume(vitals, stats, %Meta{medicine: %{stats: %{str: 1}}})

      assert reason =~ "再难精进"
    end

    test "无 medicine/food -> 空效果" do
      vitals = Vitals.new()
      stats = Stats.new()

      assert {:ok, effect} = Effect.consume(vitals, stats, %Meta{})
      assert effect.food? == false
      assert effect.medicine? == false
      assert effect.parts == []
    end
  end

  describe "Liquid (液体描述)" do
    test "extra_long 分级描述" do
      liq = %{liquid: %{remaining: 100, max: 100, name: "女儿红"}}
      assert Liquid.extra_long(liq) == "里面装满了女儿红。\n"

      liq = %{liquid: %{remaining: 80, max: 100, name: "女儿红"}}
      assert Liquid.extra_long(liq) == "里面的女儿红被喝过少许，不过依然很满。\n"

      liq = %{liquid: %{remaining: 75, max: 100, name: "女儿红"}}
      assert Liquid.extra_long(liq) == "里面装了七、八分满的女儿红。\n"

      liq = %{liquid: %{remaining: 40, max: 100, name: "女儿红"}}
      assert Liquid.extra_long(liq) == "里面装了五、六分满的女儿红。\n"

      liq = %{liquid: %{remaining: 10, max: 100, name: "女儿红"}}
      assert Liquid.extra_long(liq) == "里面装了少许的女儿红。\n"

      assert Liquid.extra_long(%{liquid: %{remaining: 0, max: 100, name: "女儿红"}}) == nil
    end
  end

  describe "Transport (可驾驶)" do
    test "is_transport?/can_drive_by?" do
      assert Transport.is_transport?(%{})

      assert Transport.can_drive_by?(%{
               owner: nil,
               me: "a",
               owner_room: nil,
               my_room: "r1"
             })

      assert Transport.can_drive_by?(%{
               owner: "a",
               me: "a",
               owner_room: "r1",
               my_room: "r1"
             })

assert Transport.can_drive_by?(%{
                owner: "b",
                me: "a",
                owner_room: "r1",
                my_room: "r2"
              })

      refute Transport.can_drive_by?(%{
                owner: "b",
                me: "a",
                owner_room: "r1",
                my_room: "r1"
              })
    end

    test "set_owner/query_owner" do
      t = %{}
      assert Transport.query_owner(Transport.set_owner(t, "a")) == "a"
    end
  end

  describe "Equip (装备/卸下)" do
    test "two_handed?/secondary? 位运算" do
      assert Equip.two_handed?(0x4)
      assert Equip.two_handed?(0x6)
      refute Equip.two_handed?(0x1)
      assert Equip.secondary?(0x2)
      assert Equip.secondary?(0x6)
      refute Equip.secondary?(0x1)
    end

    test "wield_decision: 双手需两空" do
      assert Equip.wield_decision(0x4, %{weapon: nil, secondary_weapon: nil, handing: nil}) ==
               {:weapon}

      assert {:error, msg} =
               Equip.wield_decision(0x4, %{weapon: %{flag: 0}, secondary_weapon: nil, handing: nil})

      assert msg =~ "空出双手"
    end

    test "wield_decision: 单手无武器 -> weapon" do
      assert Equip.wield_decision(0x1, %{weapon: nil, secondary_weapon: nil, handing: nil}) ==
               {:weapon}
    end

    test "wield_decision: 有主武器可作副手 -> secondary" do
      assert Equip.wield_decision(
               0x2,
               %{weapon: %{flag: 0}, secondary_weapon: nil, handing: nil}
             ) == {:secondary_weapon}
    end

    test "wield_decision: 有主武器须先放下" do
      assert {:error, msg} =
               Equip.wield_decision(
                 0x1,
                 %{weapon: %{flag: 0}, secondary_weapon: nil, handing: nil}
               )

      assert msg =~ "放下"
    end

    test "wield_decision: 原武器可副手 -> swap" do
      assert Equip.wield_decision(
               0x1,
               %{weapon: %{flag: 0x2}, secondary_weapon: nil, handing: nil}
             ) == {:swap}
    end

    test "wield_state/unequip_state 累加累减" do
      applies = %{attack: 1}
      prop = %{attack: 3, defense: 2}
      assert Equip.wield_state(applies, prop) == %{attack: 4, defense: 2}
      assert Equip.unequip_state(%{attack: 4, defense: 2}, prop) == %{attack: 1, defense: 0}
    end

    test "wear_state 护甲+prop 合并" do
      assert Equip.wear_state(%{}, 20, %{defense: 4}) == %{armor: 20, defense: 4}
      assert Equip.wear_state(%{armor: 5}, 20, nil) == %{armor: 25}
    end
  end

  describe "Cutable (切割)" do
    defp hawk_parts do
      %{
        "head" => [0, "个", "鹰头", "鹰头", "head", %{}, "割了下来", nil],
        "wing" => [1, "只", "鹰翅", "鹰翅", "wing", %{}, "切了下来", nil]
      }
    end

    test "available_parts 排除已割/no_cut" do
      assert Enum.sort(Cutable.available_parts(hawk_parts(), [])) == ["head", "wing"]

      assert Enum.sort(Cutable.available_parts(hawk_parts(), ["head"], %{})) == ["wing"]

      assert Enum.sort(Cutable.available_parts(hawk_parts(), [], %{"wing" => "割不下来"})) ==
               ["head"]
    end

    test "validate_cut 无部位 -> error" do
      assert {:error, _} = Cutable.validate_cut(nil, %{part_id: "head", been_cut: [], no_cut: %{}})
    end

    test "validate_cut 已割 -> error" do
      head = Map.get(hawk_parts(), "head")

      assert {:error, "鹰头已经被割走了。"} =
               Cutable.validate_cut(head, %{part_id: "head", been_cut: ["head"], no_cut: %{}})
    end

    test "validate_cut no_cut -> error (string 文案)" do
      head = Map.get(hawk_parts(), "head")

      assert {:error, "割不下来"} =
               Cutable.validate_cut(head, %{part_id: "head", been_cut: [], no_cut: %{"head" => "割不下来"}})
    end

    test "validate_cut 武器切割" do
      head = Map.get(hawk_parts(), "head")

      assert {:ok, msg} =
               Cutable.validate_cut(head, %{
                 part_id: "head",
                 been_cut: [],
                 no_cut: %{},
                 weapon_skill_type: "sword",
                 weapon_name: "长剑",
                 skill: %{"sword" => 120},
                 force: 100
               })

      assert msg =~ "长剑"
      assert msg =~ "鹰头"
    end

    test "validate_cut 针需剑术>=100" do
      head = Map.get(hawk_parts(), "head")

      assert {:error, _} =
               Cutable.validate_cut(head, %{
                 part_id: "head",
                 been_cut: [],
                 no_cut: %{},
                 weapon_skill_type: "pin",
                 weapon_name: "绣花针",
                 skill: %{"sword" => 10},
                 force: 100
               })
    end

    test "validate_cut 徒手内力不足" do
      head = Map.get(hawk_parts(), "head")
      assert {:error_force, "鹰头"} = Cutable.validate_cut(head, %{part_id: "head", been_cut: [], no_cut: %{}, force: 10})
    end

    test "extra_desc 摘要" do
      assert Cutable.extra_desc(hawk_parts(), [], 0) == ""
      assert Cutable.extra_desc(hawk_parts(), ["head"], 0) == "不过它的鹰头已经不见了。\n"
    end
  end

  defp _agent(initial) do
    {:ok, agent} = Agent.start_link(fn -> initial end)
    agent
  end
end

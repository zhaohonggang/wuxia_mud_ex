defmodule Kantele.Character.CombatTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff

  test "敌人增删去重" do
    combat = Combat.new()
    enemy = %{id: "npc:1", pid: self(), name: "野猪"}

    {combat, new_fight?} = Combat.add_enemy(combat, enemy)
    assert new_fight?
    assert Combat.enemy?(combat, "npc:1")

    {combat, new_fight?} = Combat.add_enemy(combat, enemy)
    refute new_fight?
    assert Enum.count(combat.enemies) == 1

    combat = Combat.remove_enemy(combat, "npc:1")
    refute Combat.fighting?(combat)
  end

  test "apply_temp 累计加成" do
    combat =
      Combat.new()
      |> Combat.apply_temp(%{attack: 10, dodge: 5})
      |> Combat.apply_temp(%{attack: -3})

    assert combat.temp.attack == 7
    assert combat.temp.dodge == 5
  end

  test "buff 添加与移除" do
    buff = %Buff{key: "liuxin-liu", applies: %{dodge: -15}}

    combat =
      Combat.new()
      |> Combat.apply_temp(%{dodge: 15})
      |> Combat.add_buff(buff)

    assert Combat.buff_active?(combat, "liuxin-liu")
    assert Enum.count(combat.buffs) == 1

    # 重复施加同 key 不叠加条目
    combat = Combat.add_buff(combat, buff)
    assert Enum.count(combat.buffs) == 1

    combat = Combat.remove_buff(combat, "liuxin-liu")
    refute Combat.buff_active?(combat, "liuxin-liu")
  end

  test "effective_applies 合并装备快照" do
    combat =
      Combat.new()
      |> Combat.apply_temp(%{damage: 5})
      |> Combat.equip(:weapon, %{name: "长剑", skill_type: "sword", damage: 22})
      |> Combat.equip(:armor, %{name: "布袍", armor: 2})

    applies = Combat.effective_applies(combat)

    assert applies.damage == 27
    assert applies.armor == 2

    combat = Combat.unequip(combat, :weapon)

    assert Combat.effective_applies(combat).damage == 5
  end

  test "start_busy 设定忙乱并取较大值（start_busy/2）" do
    combat = Combat.start_busy(Combat.new(), 3)

    assert combat.busy == 3
    assert Combat.busy?(combat)

    # 已有值更大时保留大者
    combat = Combat.start_busy(combat, 2)
    assert combat.busy == 3
    combat = Combat.start_busy(combat, 5)
    assert combat.busy == 5

    # 0 轮不生效
    assert Combat.start_busy(Combat.new(), 0).busy == 0
    refute Combat.busy?(Combat.new())
  end

  test "interrupt 清零忙乱（interrupt_me）" do
    combat = Combat.new() |> Combat.start_busy(4) |> Combat.interrupt()

    assert combat.busy == 0
    refute Combat.busy?(combat)
  end
end

defmodule Kantele.Character.Combat.Buff do
  @moduledoc """
  生效中的临时增益（对应 LPC 的 temp buff + start_call_out 定时移除）
  """

  defstruct [:key, :applies]
end

defmodule Kantele.Character.Combat do
  @moduledoc """
  角色的战斗运行时状态，存放在 `character.meta.combat`

  - `enemies` 当前敌人引用列表 `%{id, pid, name, room_id}`
  - `busy` 忙乱轮数，防御按 dp/3 计算（对应 LPC start_busy/is_busy）
  - `jiali` 加力，攻击时消耗内力换取伤害
  - `dead` 死亡标记，防止尸体继续行动
  - `buffs` 生效中的临时增益
  - `equipped` 装备中的武器/护甲 instance id
  - `temp` 临时加成表（buff + NPC apply 合并），对应 LPC temp dbase 的 apply/*
  """

  alias Kantele.Character.Combat.Buff

  defstruct enemies: [],
            busy: 0,
            jiali: 0,
            dead: false,
            buffs: [],
            equipped: %{},
            temp: %{},
            attacked_by: MapSet.new()

  @applies_keys [:attack, :defense, :damage, :unarmed_damage, :dodge, :parry, :armor]

  # 护甲槽位白名单（对照 LPC equip.c 的 armor_type；cloth=衣袍，body 归一化为 cloth）
  @armor_slots ~w(cloth head feet waist hands neck cloak finger)

  def armor_slots(), do: @armor_slots

  def applies_keys(), do: @applies_keys

  def new() do
    %__MODULE__{temp: Map.new(@applies_keys, fn key -> {key, 0} end), equipped: %{}}
  end

  @doc "记录仇恨来源（A9/P11：被打过的人记下来，内存态不落盘）"
  def record_attacked_by(%__MODULE__{} = combat, id) do
    %{combat | attacked_by: MapSet.put(combat.attacked_by, id)}
  end

  @doc "仇恨 id 列表（aggressive 重开战时优先找这些人）"
  def attacked_by_ids(%__MODULE__{} = combat),
    do: MapSet.to_list(combat.attacked_by)

  @doc "新敌人入列（去重），返回是否为新开战"
  def add_enemy(%__MODULE__{} = combat, enemy) do
    if enemy?(combat, enemy.id) do
      {combat, false}
    else
      {%{combat | enemies: combat.enemies ++ [enemy]}, Enum.empty?(combat.enemies)}
    end
  end

  def enemy?(%__MODULE__{} = combat, id),
    do: Enum.any?(combat.enemies, &(&1.id == id))

  def remove_enemy(%__MODULE__{} = combat, id) do
    %{combat | enemies: Enum.reject(combat.enemies, &(&1.id == id))}
  end

  def fighting?(%__MODULE__{} = combat), do: not Enum.empty?(combat.enemies)

  @doc "应用临时加成（正负皆可）"
  def apply_temp(%__MODULE__{} = combat, applies) do
    temp =
      Enum.reduce(applies, combat.temp, fn {key, value}, temp ->
        Map.update(temp, key, value, &(&1 + value))
      end)

    %{combat | temp: temp}
  end

  def add_buff(%__MODULE__{} = combat, %Buff{} = buff) do
    buffs = Enum.reject(combat.buffs, &(&1.key == buff.key))
    %{combat | buffs: buffs ++ [buff]}
  end

  def remove_buff(%__MODULE__{} = combat, key) do
    %{combat | buffs: Enum.reject(combat.buffs, &(&1.key == key))}
  end

  def buff_active?(%__MODULE__{} = combat, key),
    do: Enum.any?(combat.buffs, &(&1.key == key))

  @doc """
  结算后的实际加成表：temp 加成 + 全部已装备槽位的基础值与多键 prop 合并

  每个槽位快照：武器 `%{name, skill_type, damage, prop}`，
  护甲 `%{name, armor, prop}`；prop 仅 @applies_keys 白名单键。
  （b6/B4 多槽位：cloth/head/waist 等同时生效，对应 LPC 多部位护甲叠加）
  """
  def effective_applies(%__MODULE__{} = combat) do
    Enum.reduce(combat.equipped, combat.temp, fn {_slot, snap}, applies ->
      applies
      |> bump(:damage, Map.get(snap, :damage) || 0)
      |> bump(:armor, Map.get(snap, :armor) || 0)
      |> apply_snapshot_prop(Map.get(snap, :prop))
    end)
  end

  defp bump(applies, _key, 0), do: applies
  defp bump(applies, key, value), do: Map.update(applies, key, value, &(&1 + value))

  defp apply_snapshot_prop(applies, nil), do: applies

  defp apply_snapshot_prop(applies, prop) when is_map(prop) do
    Enum.reduce(prop, applies, fn {key, value}, acc ->
      Map.update(acc, key, value, &(&1 + value))
    end)
  end

  @doc "穿戴到指定槽位（weapon 或 armor_slots 内的槽位；同槽互斥由命令层把关）"
  def equip(%__MODULE__{} = combat, slot, meta) when is_atom(slot) do
    put_in(combat.equipped[slot], meta)
  end

  def unequip(%__MODULE__{} = combat, slot), do: %{combat | equipped: Map.delete(combat.equipped, slot)}

  @doc "槽位是否已被占用（同槽互斥，命令层调用）"
  def occupied?(%__MODULE__{equipped: equipped}, slot), do: Map.has_key?(equipped, slot)

  @doc "武器快照（无则 nil）"
  def weapon(%__MODULE__{} = combat), do: Map.get(combat.equipped, :weapon)

  def busy?(%__MODULE__{busy: busy}), do: busy > 0
end

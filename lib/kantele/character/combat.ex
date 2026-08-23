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
            temp: %{}

  @applies_keys [:attack, :defense, :damage, :unarmed_damage, :dodge, :parry, :armor]

  def new() do
    %__MODULE__{temp: Map.new(@applies_keys, fn key -> {key, 0} end), equipped: %{}}
  end

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
  结算后的实际加成表：temp 加成 + 装备快照带来的武器伤害/护甲

  `equipped` 中保存武器/护甲的元数据快照（wield/wear 时写入），
  这样房间侧无需访问角色背包即可构建战斗数据
  """
  def effective_applies(%__MODULE__{} = combat) do
    weapon = Map.get(combat.equipped, :weapon)
    armor = Map.get(combat.equipped, :armor)

    combat.temp
    |> Map.update(:damage, 0, &(&1 + equip_value(weapon, :damage)))
    |> Map.update(:armor, 0, &(&1 + equip_value(armor, :armor)))
  end

  defp equip_value(nil, _key), do: 0
  defp equip_value(meta, key), do: Map.get(meta, key, 0)

  @doc "穿戴武器快照"
  def equip(%__MODULE__{} = combat, :weapon, meta) do
    put_in(combat.equipped[:weapon], meta)
  end

  def equip(%__MODULE__{} = combat, :armor, meta) do
    put_in(combat.equipped[:armor], meta)
  end

  def unequip(%__MODULE__{} = combat, slot), do: %{combat | equipped: Map.delete(combat.equipped, slot)}

  @doc "武器快照（无则 nil）"
  def weapon(%__MODULE__{} = combat), do: Map.get(combat.equipped, :weapon)

  def busy?(%__MODULE__{busy: busy}), do: busy > 0
end

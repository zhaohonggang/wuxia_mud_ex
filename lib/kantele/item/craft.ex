defmodule Kantele.Item.Craft do
  @moduledoc """
  自制道具等级/属性（对应 `feature/itemmake.c`）

  纯计算部分：
  - `weapon_level/1`: 按 `owner` 累积 & `/100` clamps 到等级阈值；满级 + magic → ULTRA
  - `armor_level/1`: 防御等级（暂恒 0）
  - `is_equiped_weapon?/1` / `is_unarmed_weapon?/1`: 武器/空手判型
  - `apply_damage/1` / `apply_armor/1`: 攻/防结算
  - `chinese_s/1`: 魔力属性中文（cold/fire/magic/lighting）
  - `item_owner/2`: 由物品 id 解析主人（LPC 由文件名解析）

  等级阈值对照 itemmake.c：#define（5/10/30/100/300/1000/3000/10000/50000）。
  """
  alias Kantele.Item.Craft.Level

  @doc "是否自制道具 (is_item_make)"
  def is_item_make?(_), do: true

  @doc "攻击等级：owner 各键求和 /100，clamp 到 MAX_LEVEL；满且 magic(power/imbue_ok) → ULTRA"
  def weapon_level(owner, magic \\ %{}) do
    total = if is_map(owner), do: Enum.reduce(owner, 0, fn {_k, v}, acc -> acc + v end), else: 0
    lvl = div(total, 100)

    lvl =
      if lvl > Level.max(), do: Level.max(), else: lvl

    if lvl == Level.max() and (Map.get(magic, :power) || Map.get(magic, :imbue_ok)) do
      Level.ultra()
    else
      lvl
    end
  end

  @doc "防御等级（暂恒 0，LPC armor_level 未实现）"
  def armor_level(_), do: 0

  @doc "是否已装备武器 (is_equiped_weapon)"
  def is_equiped_weapon?(meta), do: is_binary(Map.get(meta, :skill_type))

  @doc "是否空手武器装备 (is_unarmed_weapon)"
  def is_unarmed_weapon?(meta), do: Map.get(meta, :armor_type) == "hands"

  @doc "item_long 是否走武器长描述"
  def item_long?(meta), do: is_equiped_weapon?(meta) or is_unarmed_weapon?(meta)

  @doc "apply_damage：按等级平方/81 加权 point，再加圣化 bless*2"
  def apply_damage(level, point, bless) do
    lvl = Level.rank(level)
    p = div(point, 2)
    d = trunc(Float.round(1.0 * (lvl * lvl) / (9 * 9) * p)) + bless * 2
    d + p
  end

  @doc "apply_armor：point + bless*2（LPC 简化算法）"
  def apply_armor(point, bless) do
    point + bless * 2
  end

  @doc "魔力属性中文 (chinese_s)：cold/fire/magic/lighting"
  def chinese_s(nil), do: "无"
  def chinese_s("cold"), do: "冰"
  def chinese_s("fire"), do: "火"
  def chinese_s("magic"), do: "魔"
  def chinese_s("lighting"), do: "电"
  def chinese_s(_), do: "无"

  @doc "item_owner：由物品 id 解析主人（LPC 由 ITEM_DIR %s-%s 文件名解析）"
  def item_owner(item_id) when is_binary(item_id) do
    case Regex.run(~r/^(.+)-[^-]+$/, item_id) do
      [_, owner] -> owner
      _ -> nil
    end
  end

  def item_owner(_), do: nil

  defmodule Level do
    @moduledoc "itemmake.c 等级阈值与换算"

    @levels [5, 10, 30, 100, 300, 1000, 3000, 10_000, 50_000]
    @max 50_000
    @ultra 50_001

    @doc "等级阈值表"
    def levels(), do: @levels

    @doc "MAX_LEVEL（满级）"
    def max(), do: @max

    @doc "ULTRA_LEVEL（无上神品）"
    def ultra(), do: @ultra

    @doc "攻击等级 → 1..9（LPC: while(--lvl) if(attack_lvl>=levels[lvl]) break; lvl++）"
    def rank(attack_lvl) when is_integer(attack_lvl) do
      # LPC 循环从 lvl=8 递减到 1 判断，levels[0]=5 永不参与 → 用 tl() 剔除之
      count = Enum.count(tl(@levels), fn threshold -> attack_lvl >= threshold end)
      count + 1
    end

    def rank(_), do: 0
  end
end

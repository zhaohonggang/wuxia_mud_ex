defmodule Kantele.World.Items do
  @moduledoc false

  use Kalevala.Cache
end

defmodule Kantele.World.Item do
  @moduledoc """
  Local callbacks for `Kalevala.World.Item`
  """

  use Kalevala.World.Item

  @doc """
  物品名匹配：全名精确或按第一个词前缀匹配

  双语名（如 "长剑 Changjian"）允许玩家只输入中文名 "长剑"
  """
  def matches?(item, keyword) do
    keyword = String.downcase(String.trim(keyword))
    name = String.downcase(item.name)

    name == keyword or String.starts_with?(name, "#{keyword} ")
  end
end

defmodule Kantele.World.Item.Meta.Book do
  @moduledoc """
  秘籍类物品的可研习信息（对应 LPC 秘籍的 skill mapping，裁剪自 study 流程）

  - `skill` 可研习的技能 id（如 "literate"）
  - `min_skill` / `max_skill` 有效研习区间，低于/超出均无收获（study.c）
  - `exp_required` 实战经验门槛（combat_exp）
  - `jing_cost` 每次研习的精力消耗
  - `difficulty` 难度基准（LPC 用于消耗公式 `(jing_cost*20 + difficulty - int)/20`）

  本期只解析存储；消费端（研习命令/耗精公式）由 b 期 learn 重构接入。
  """

  defstruct [:skill, :min_skill, :max_skill, :exp_required, :jing_cost, :difficulty]
end

defmodule Kantele.World.Item.Meta do
  @moduledoc """
  Item metadata, implements `Kalevala.Meta`

  战斗相关扩展字段（由世界数据 `meta = {}` 块解析）：

  - `damage` 武器伤害值（对应 LPC init_sword/1）
  - `skill_type` 武器技能类型，如 "sword"（对应 query skill_type）
  - `armor` 护甲值（对应 LPC armor_prop/armor）
  - `value` 价值

  通用/消耗品类扩展字段（A4/D1，对应 LPC set_weight/unit/material 等）：

  - `weight` 重量（整数，LPC 单位为克）
  - `unit` 量词（如 "个"、"本"，用于文案展示）
  - `material` 材质（如 "silk"、"bone"）
  - `food` 饱食度供给（对应 LPC food_supply；饥饿系统消费端属 O4）
  - `medicine` 药效 map（原样透传，如 `%{qi: 50, stats: %{str: 1}}`；消费端见 A7）
  - `book` 秘籍五元组 `%Meta.Book{}`（消费端研习命令属 b 期）
  """

  defstruct [
    :damage,
    :skill_type,
    :armor,
    :value,
    :weight,
    :unit,
    :material,
    :food,
    :medicine,
    :book
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:damage, :armor])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

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

defmodule Kantele.World.Item.Meta do
  @moduledoc """
  Item metadata, implements `Kalevala.Meta`

  战斗相关扩展字段（由世界数据 `meta = {}` 块解析）：

  - `damage` 武器伤害值（对应 LPC init_sword/1）
  - `skill_type` 武器技能类型，如 "sword"（对应 query skill_type）
  - `armor` 护甲值（对应 LPC armor_prop/armor）
  - `value` 价值
  """

  defstruct [:damage, :skill_type, :armor, :value]

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

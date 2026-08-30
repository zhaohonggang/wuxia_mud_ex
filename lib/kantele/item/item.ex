defmodule Kantele.Item do
  @moduledoc """
  物品系统核心（对应 LPC item 系统）

  提供物品基础结构、动词系统、装备/使用逻辑。
  """

  @doc """
  使用此模块可获得物品通用功能：
  - item_def/0 返回物品定义
  - can_use?/2 可用性检查
  - execute/2 执行逻辑
  """
  defmacro __using__(_opts) do
    quote do
      import Kantele.Item
    end
  end

  defmodule Item do
    @moduledoc "物品基础结构"

    @type t :: %__MODULE__{
      id: String.t(),
      name: String.t(),
      type: String.t(),
      weight: non_neg_integer(),
      value: non_neg_integer(),
      verb: String.t() | nil,
      description: String.t(),
      no_sell: boolean(),
      attrs: map()
    }

    defstruct [
      :id,
      :name,
      :type,
      :weight,
      :value,
      :verb,
      :description,
      :no_sell,
      attrs: %{}
    ]

    @doc "创建物品"
    def new(attrs) do
      struct(__MODULE__, attrs)
    end

    @doc "检查是否有指定动词"
    def has_verb?(%__MODULE__{verb: verb}, verb_name), do: verb == verb_name

    @doc "获取物品动词"
    def get_verb(%__MODULE__{verb: verb}), do: verb

    @doc "检查是否可售"
    def sellable?(%__MODULE__{no_sell: no_sell}), do: not no_sell
  end

  defmodule ItemRegistry do
    @moduledoc """
    物品注册表（唯一物品追踪）
    """

    @static %{}
    @registry_name __MODULE__

    def register(id, item_def) when is_binary(id) and is_map(item_def) do
      :persistent_term.put({@registry_name, :extra}, Map.put(extras(), id, item_def))
      :ok
    end

    def unregister(id) when is_binary(id) do
      :persistent_term.put({@registry_name, :extra}, Map.delete(extras(), id))
      :ok
    end

    def all(), do: Map.merge(@static, extras())

    def get(id) when is_binary(id), do: Map.get(all(), id)
    def get(_id), do: nil

    def known?(id), do: Map.has_key?(all(), id)

    defp extras() do
      :persistent_term.get({@registry_name, :extra}, %{})
    end
  end

  defmodule ItemInstance do
    @moduledoc "物品实例（运行态）"

    defstruct [
      :id,
      :item_id,
      :owner_id,
      :location,  # :inventory, :equipped, :room, :ground
      :room_id,
      attrs: %{}
    ]

    @doc "创建物品实例"
    def new(id, item_id, attrs \\ %{}) do
      %__MODULE__{
        id: id,
        item_id: item_id,
        owner_id: nil,
        location: :inventory,
        room_id: nil,
        attrs: attrs
      }
    end

    @doc "检查是否装备中"
    def equipped?(%__MODULE__{location: :equipped}), do: true
    def equipped?(_), do: false

    @doc "检查是否在背包"
    def in_inventory?(%__MODULE__{location: :inventory}), do: true
    def in_inventory?(_), do: false
  end

  @doc "检查玩家是否手持某物品"
  def is_handing?(player, item_id) do
    # 简化实现：检查背包中是否有该物品且标记为手持
    false
  end

  @doc "检查玩家是否持有某物品"
  def has?(player, item_id) do
    # 简化实现
    false
  end

  @doc "检查物品是否为货币"
  def is_currency?(_item), do: false

  @doc "检查物品是否为尸体"
  def is_corpse?(_item), do: false

  @doc "获取物品技能类型（兵器类型）"
  def get_skill_type(_item), do: "sword"

  @doc "获取物品动作列表"
  def get_actions(_item), do: []

  @doc "检查是否为针灸工具"
  def is_acupuncture_tool?(%Item{type: "acupuncture_tool"}), do: true
  def is_acupuncture_tool?(_), do: false

  @doc "检查是否为秘籍"
  def is_secret_manual?(%Item{type: "secret_manual"}), do: true
  def is_secret_manual?(_), do: false

  @doc """
  获取物品类型中文描述（对应 LPC inherit/item/item.c type()）

  根据 meta 中的标记返回物品类型字符串：
  - is_weapon? → "武器"
  - is_armor? → "防具"
  - is_food? → "食物"
  - is_liquid? → "饮具"
  - is_container? → "容器"
  - is_book? → "书物"
  - is_money? → "货币"
  - is_charm? → "护身符"
  - is_rune? → "符文"
  - is_inlaid? → "镶嵌物"
  - is_task? → "任务物品"
  - 默认 → "杂物"
  """
  def type(meta) when is_map(meta) do
    cond do
      meta["is_weapon"] -> "武器"
      meta["is_armor"] -> "防具"
      meta["is_food"] -> "食物"
      meta["is_liquid"] -> "饮具"
      meta["is_container"] -> "容器"
      meta["is_book"] -> "书物"
      meta["is_money"] -> "货币"
      meta["is_charm"] -> "护身符"
      meta["is_rune"] -> "符文"
      meta["is_inlaid"] -> "镶嵌物"
      meta["is_task"] -> "任务物品"
      true -> "杂物"
    end
  end
end
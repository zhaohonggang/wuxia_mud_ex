defmodule Kantele.World.Item.Liquid do
  @moduledoc """
  容器液体的读写（对应 LPC `set("liquid", ([...]))` 与 `liquid/remaining`）。

  LPC 里 `liquid` 是**对象上的 mapping**，喝一口就 `add("liquid/remaining", -1)`
  —— 状态跟着**对象实例**走，不跟定义走。本引擎的物品定义
  （`%Kalevala.World.Item{}`）是全局共享、只读的，所以拆成两层：

  - **定义侧**：`Item.Meta.liquid` 存 `create()` 里给的**初始**状态
    （`%{type: "alcohol", name: "米酒", remaining: 15, drunk_apply: 3}`），
    由 `scripts/backfill_item_liquid.py` 从 LPC 源回填。
  - **运行时侧**：`%Kalevala.World.Item.Instance{}.meta` 里四个字符串键
    `"liquid_remaining"` / `"liquid_name"` / `"liquid_type"` /
    `"liquid_drunk_apply"`。每次喝/灌只改实例、不动定义，否则一个玩家喝光
    会让所有玩家的同一个酒袋都空掉。

  运行时键为 nil 时退回定义值（`state/2` 负责这个回退），所以**未回填过
  `liquid` 的物品**、以及**旧存档里没有液体键的实例**都行为一致。

  ## 持久化

  `Kantele.Character.Records` 的 `inventory` 列只存 `item_id`。本模块提供
  `serialize/1` / `restore/2` 让上面四个键随背包落盘 —— **只**这四个，
  不碰 `:book`：秘籍的随机标题按 LPC「驱动重启后重跑 `create()`」的语义
  每次登录重掷，不能被存档固化（见 `Records.restore_inventory/2` 注释）。
  """

  # 注意：`type` 那个键不能用 `@type` 命名（Elixir 保留给 typespec），故一律加 `key_` 前缀。
  @key_remaining "liquid_remaining"
  @key_name "liquid_name"
  @key_type "liquid_type"
  @key_drunk "liquid_drunk_apply"

  @doc """
  定义侧初始液体状态（`Item.Meta.liquid`）；无 `liquid` 返回 nil。

  `liquid` 由 loader 归一化过：`remaining` 一定是整数，其余数值键若存在也已是整数。
  """
  def definition(%Kalevala.World.Item{} = item) do
    case Map.get(item, :meta) do
      %{liquid: liquid} when is_map(liquid) -> liquid
      _ -> nil
    end
  end

  def definition(_), do: nil

  @doc """
  实例的当前液体状态；物品定义没有 `liquid` 时返回 nil（调用方走别的分支）。

  返回 `%{remaining: integer, name: binary | nil, type: binary | nil,
  drunk_apply: integer, max: integer | nil}`。
  """
  def state(%Kalevala.World.Item{} = item, instance) do
    case definition(item) do
      nil ->
        nil

      liquid ->
        meta = instance_meta(instance)

        %{
          remaining: int_or(Map.get(meta, @key_remaining), Map.get(liquid, :remaining), 0),
          name: Map.get(meta, @key_name) || Map.get(liquid, :name),
          type: Map.get(meta, @key_type) || Map.get(liquid, :type),
          drunk_apply: int_or(Map.get(meta, @key_drunk), Map.get(liquid, :drunk_apply), 0),
          max: Map.get(liquid, :max) || max_liquid(item)
        }
    end
  end

  @doc "把状态写回实例 meta（只写四个液体键，其余 meta 原样保留）"
  def put_state(instance, state) do
    meta = instance_meta(instance)

    meta =
      meta
      |> Map.put(@key_remaining, state.remaining)
      |> put_present(@key_name, Map.get(state, :name))
      |> put_present(@key_type, Map.get(state, :type))
      |> put_present(@key_drunk, Map.get(state, :drunk_apply))

    %{instance | meta: meta}
  end

  @doc "液体是否已喝空（`remaining <= 0`）"
  def empty?(%{remaining: remaining}), do: not is_integer(remaining) or remaining <= 0

  @doc """
  序列化实例的液体键，供 `Records` 存进 `inventory` 数组项。

  没有液体键时返回 `%{}`（旧格式，向后兼容）。
  """
  def serialize(instance) do
    meta = instance_meta(instance)

    for key <- [@key_remaining, @key_name, @key_type, @key_drunk],
        value = Map.get(meta, key),
        not is_nil(value),
        into: %{},
        do: {key, value}
  end

  @doc """
  从存档项恢复液体键；`entry` 无液体键时原样返回实例（旧存档兼容）。
  """
  def restore(instance, entry) when is_map(entry) do
    restored =
      for key <- [@key_remaining, @key_name, @key_type, @key_drunk],
          value = Map.get(entry, key),
          not is_nil(value),
          into: %{},
          do: {key, value}

    if restored == %{} do
      instance
    else
      %{instance | meta: Map.merge(instance_meta(instance), restored)}
    end
  end

  def restore(instance, _), do: instance

  defp instance_meta(%{meta: meta}) when is_map(meta), do: meta
  defp instance_meta(_), do: %{}

  defp max_liquid(%Kalevala.World.Item{} = item) do
    case Map.get(item, :meta) do
      %{max_liquid: max} -> max
      _ -> nil
    end
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp int_or(value, _fallback, _default) when is_integer(value), do: value
  defp int_or(_value, fallback, _default) when is_integer(fallback), do: fallback
  defp int_or(_value, _fallback, default), do: default
end

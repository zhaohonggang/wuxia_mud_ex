defmodule Kantele.Npc.Dealer do
  @moduledoc """
  商人（对应 `feature/dealer.c`）

  便携纯逻辑：估价/收购/标价/购买的价格计算。所有决策都是纯函数，
  宿主负责提供物品描述与执行实体副作用（move、MONEY_D pay）。

  物品统一用 item_map 描述，可含字段：
  - `:name`、`:id`、`:unit`、`:amount`（可叠加对象数量，无则为 1）
  - `:value`（单件价值）、`:base_value`（叠加对象基础价值）
  - `:consistence`（成色，%)、`:money_id`、`:is_character?`、`:no_drop?`
  - `:no_sell`（字符串拒绝语）或 `:no_sell?`、`:food_supply?`、`:shaolin?`、`:mingjiao?`
  - `:equipped?`

  resale 系数 = 3/10（do_value / do_sell 回售）。
  """

  @resale 3 * 10

  @doc "is_vendor_good（do_buy 补货查目录）：按 id 或去色名命中商品；未命中 :error"
  def is_vendor_good(goods, arg) when is_map(goods) do
    goods
    |> Enum.find_value(:error, fn {key, item} ->
      cond do
        Map.get(item, :id) == arg -> key
        strip_color(Map.get(item, :name, "")) == arg -> key
        true -> nil
      end
    end)
  end

  @doc "估价（do_value/3）：返回 `{:ok, value, reason?}` 或 `{:reject, message}`"
  def do_value(item) do
    cond do
      Map.get(item, :money_id) -> {:reject, "你没用过钱啊？"}
      Map.get(item, :is_character?, false) -> {:reject, "这你也拿来估价？"}
      true -> do_value_value(item)
    end
  end

  defp do_value_value(item) do
    base = appraisal_value(item)

    cond do
      base < 1 -> {:reject, "一文不值！"}
      Map.get(item, :no_drop?, false) or no_sell?(item) -> {:reject, no_sell_reason(item)}
      true -> {:ok, div(base * @resale, 100)}
    end
  end

  @doc "收购价计算（do_sell/3 的价格部分）：返回 `{:ok, value}` 或 `{:reject, message}`"
  def do_sell(item, amount) do
    max_count = Map.get(item, :amount, 1)

    cond do
      amount < 1 -> {:reject, "亏你想的出来，有这样卖东西的吗？"}
      max_count < 1 and amount > 1 -> {:reject, "这种东西不能拆开来卖。"}
      max_count >= 1 and amount > max_count -> {:reject, "你身上没有这么多。"}
      Map.get(item, :money_id) -> {:reject, "你想卖「钱」？"}
      Map.get(item, :is_character?, false) -> {:reject, "我这里做正经生意，不贩卖这些！"}
      Map.get(item, :no_drop?, false) or no_sell?(item) -> {:reject, no_sell_reason(item)}
      Map.get(item, :food_supply?) -> {:reject, "剩菜剩饭留给您自己用吧。"}
      Map.get(item, :shaolin?) -> {:reject, "小的胆子很小，可不敢买少林庙产。"}
      Map.get(item, :mingjiao?) -> {:reject, "小的只有一个脑袋，可不敢买魔教的东西。"}
      true -> {:ok, sell_value(item, amount)}
    end
  end

  @doc "购买价计算（do_buy/3 价格部分）"
  # val_factor: 现金货按库存价（当前手里现货 12，目录补货 10），与 dealer.c 一致
  def do_buy(item, amount, goods, opts \\ %{}) do
    val_factor = Map.get(opts, :val_factor, 10)

    cond do
      not is_integer(amount) or amount < 1 or amount > 100 -> {:reject, "慢慢来，一次最多买一百件。"}
      Map.get(item, :money_id) -> {:reject, "你要买钱？有意思！"}
      amount > 1 and Map.get(item, :amount, 1) < 1 -> {:reject, "只能一个一个的买。"}
      true -> do_buy_value(item, amount, goods, val_factor, opts)
    end
  end

  defp do_buy_value(item, amount, goods, val_factor, opts) do
    value = Map.get(item, :value, 0)

    if value > 100_000_000 do
      {:reject, "这么大一笔生意？我可不好做。"}
    else
      value = div(value * val_factor, 10)

      value =
        case Map.get(goods, Map.get(item, :file, "")) do
          v when is_integer(v) and v > 0 -> v * amount
          _ -> value * amount
        end

      value = if Map.get(opts, :shop_owner?, false), do: div(value * 4, 5), else: value

      {:ok, value}
    end
  end

  @doc "do_list 的商品聚合（库存 + 目录），返回 `[%{short, unit, price, count}]`"
  # count: -1 大量供应（目录），>0 现货（库存叠加数量）
  def build_list(inventory, goods) do
    inv_rows =
      inventory
      |> Enum.reject(fn i ->
        Map.get(i, :equipped?, false) || Map.get(i, :money_id) ||
          Map.get(i, :is_character?, false)
      end)

    inv_map = aggregate_inventory(inv_rows, %{})

    goods_map =
      goods
      |> Enum.reduce(%{}, fn {key, item}, acc ->
        short = short_name(item)

        price =
          if is_integer(Map.get(goods, key)) and Map.get(goods, key) > 0,
            do: Map.get(goods, key),
            else: Map.get(item, :value, 0)

        Map.put(acc, short, %{
          short: short,
          unit: Map.get(item, :unit, "个"),
          price: price,
          count: -1
        })
      end)

    Map.merge(inv_map, goods_map, fn _short, inv, gd ->
      %{
        short: Map.get(gd, :short, Map.get(inv, :short)),
        unit: Map.get(gd, :unit, Map.get(inv, :unit)),
        price: Map.get(inv, :price),
        count: Map.get(inv, :count, -1)
      }
    end)
    |> Map.values()
  end

  defp aggregate_inventory([], acc), do: acc

  defp aggregate_inventory([item | rest], acc) do
    short = short_name(item)
    count = if Map.get(item, :base_unit), do: Map.get(item, :amount, 1), else: 1

    acc =
      case acc do
        %{^short => existing} ->
          Map.put(acc, short, %{existing | count: Map.get(existing, :count, 0) + count})

        _ ->
          Map.put(acc, short, %{
            short: short,
            unit: Map.get(item, :unit, "个"),
            price: Map.get(item, :value, 0),
            count: count
          })
      end

    aggregate_inventory(rest, acc)
  end

  defp appraisal_value(item) do
    base =
      if Map.get(item, :amount), do: Map.get(item, :base_value, 0), else: Map.get(item, :value, 0)

    if Map.get(item, :consistence), do: div(base * Map.get(item, :consistence), 100), else: base
  end

  defp sell_value(item, amount) do
    value =
      if Map.get(item, :amount, 1) > 1,
        do: Map.get(item, :base_value, 0) * amount,
        else: Map.get(item, :value, 0)

    value =
      if Map.get(item, :consistence),
        do: div(value * Map.get(item, :consistence), 100),
        else: value

    div(value * @resale, 100)
  end

  defp no_sell?(item) do
    Map.get(item, :no_sell?, false) || is_binary(Map.get(item, :no_sell))
  end

  defp no_sell_reason(item) do
    case Map.get(item, :no_sell) do
      s when is_binary(s) -> s
      _ -> "这东西有点古怪，我可不好估价。"
    end
  end

  defp short_name(%{name: n, id: i}), do: n <> "(" <> i <> ")"
  defp short_name(_), do: ""

  defp strip_color(str) when is_binary(str) do
    String.replace(str, ~r/\e\[[0-9;]*m/, "")
  end

  defp strip_color(_), do: ""
end

defmodule Kantele.Economy.Money do
  @moduledoc """
  货币引擎（对应 `feature/finance.c` + `MONEY_D`）

  面额：1 铜(coin) = 1，1 银(silver) = 100，1 金(gold) = 10000。

  本框架以"扁平铜钱数"作为唯一存量（`meta.coins`），此处提供面额换算/支付/
  显示三组纯函数。`money_map` 形如 `%{"gold" => g, "silver" => s, "coin" => c}`
  表示储物里的各面额枚数，用于移植 finance.c/banker.c 的分币逻辑。
  """

  @denominations %{"gold" => 10_000, "silver" => 100, "coin" => 1}
  @order ["gold", "silver", "coin"]

  @doc "面额 -> 基础值映射"
  def denominations(), do: @denominations

  @doc "把扁平铜钱数拆成面额枚数 `%{gold, silver, coin}`（大额优先，整除拆分）"
  def split(value) when is_integer(value) and value >= 0 do
    Enum.reduce(@order, {value, %{}}, fn denom, {remaining, acc} ->
      base = Map.fetch!(@denominations, denom)
      {n, rem} = {div(remaining, base), rem(remaining, base)}
      {rem, Map.put(acc, denom, n)}
    end)
    |> elem(1)
  end

  @doc """
  某 money_map 的总铜钱价值（对应 finance.c 遍历 gold/silver/coin 累加 value）
  """
  def total_value(money_map) when is_map(money_map) do
    Enum.reduce(@order, 0, fn denom, acc ->
      amount = Map.get(money_map, denom, 0)
      acc + amount * Map.fetch!(@denominations, denom)
    end)
  end

  def total_value(_), do: 0

  @doc """
  can_afford（忠实移植 finance.c，返回 0/1/2）

  - 0: 完全不够
  - 1: 有足够对应面额可付
  - 2: 总量够，但找不开零钱
  """
  def can_afford(money_map, amount) when is_integer(amount) and amount >= 0 do
    total = total_value(money_map)

    if total < amount do
      0
    else
      amount = amount - amount_value(money_map, "coin")

      if amount <= 0,
        do: 1,
        else:
          if(rem(amount, 100) != 0,
            do: 2,
            else: afford_silver(money_map, amount)
          )
    end
  end

  defp afford_silver(money_map, amount) do
    amount = amount - amount_value(money_map, "silver")
    if amount <= 0, do: 1, else: if(rem(amount, 10_000) != 0, do: 2, else: 1)
  end

  @doc """
  支付：从 money_map 扣除 amount，返回 `{:ok, new_map}` 或 `:error`

  按总额扣除，余额自动拆成三面额找零（比 finance.c 的原子扣减更通用，
  不要求持有对应小额面额即可找零）。
  """
  def pay(money_map, amount) when is_integer(amount) and amount >= 0 do
    total = total_value(money_map)

    if total < amount do
      :error
    else
      {:ok, split(total - amount)}
    end
  end

  @doc "金额显示（对应 MONEY_D->money_str）：大额用金/银/铜中文串"
  def money_str(amount) when is_integer(amount) and amount >= 0 do
    map = split(amount)

    parts =
      @order
      |> Enum.map(fn denom ->
        n = Map.get(map, denom, 0)
        if n > 0, do: "#{chinese(n)}" <> unit_of(denom), else: nil
      end)
      |> Enum.reject(&is_nil/1)

    case parts do
      [] -> "一文钱"
      [single] -> single
      multi -> Enum.join(multi, "又")
    end
  end

  defp unit_of("gold"), do: "两黄金"
  defp unit_of("silver"), do: "两白银"
  defp unit_of("coin"), do: "文铜钱"

  @doc """
  按**指定面额**格式化枚数（对应 LPC `chinese_number(n) + 单位`）。

  与 `money_str/1` 的区别：`money_str/1` 收的是**总价值**，会按 金 → 银 → 铜
  自动拆成最简组合；本函数收的是「某一种面额的枚数」，原样显示、不折算。

  `bank convert` 的成交文案需要后者 —— LPC 说的是「五两白银换五百文铜钱」，
  两边的**单位不同**，用 `money_str/1` 会把 500 文渲染成「五两白银」。

      iex> Money.denom_str(5, "silver")
      "五两白银"

      iex> Money.denom_str(500, "coin")
      "五百文铜钱"
  """
  def denom_str(count, denom) when is_integer(count) and count >= 0 do
    chinese(count) <> unit_of(denom)
  end

  @digits ~w(零 一 二 三 四 五 六 七 八 九)

  defp chinese(0), do: "零"

  defp chinese(n) when n < 10_000, do: group(n)

  defp chinese(n) when n < 100_000_000 do
    high = div(n, 10_000)
    low = rem(n, 10_000)

    cond do
      low == 0 -> group(high) <> "万"
      low < 1_000 -> group(high) <> "万零" <> group(low)
      true -> group(high) <> "万" <> group(low)
    end
  end

  # 超过亿级没有中文读法的必要（钱数是有限资源），退化为阿拉伯数字
  defp chinese(n), do: Integer.to_string(n)

  # 1..9999 的中文读法（10..19 读「十X」而不是「一十X」，与 LPC chinese_number 一致）
  defp group(n) do
    digits = Integer.digits(n)
    count = length(digits)

    {parts, _state} =
      digits
      |> Enum.with_index()
      |> Enum.reduce({[], :start}, fn {digit, index}, {acc, state} ->
        position = count - index

        cond do
          digit == 0 ->
            {acc, :zero}

          state == :start and digit == 1 and position == 2 ->
            {acc ++ ["十"], :normal}

          state == :zero ->
            {acc ++ ["零", digit_of(digit) <> unit(position)], :normal}

          true ->
            {acc ++ [digit_of(digit) <> unit(position)], :normal}
        end
      end)

    Enum.join(parts)
  end

  defp digit_of(digit), do: Enum.at(@digits, digit)

  defp unit(1), do: ""
  defp unit(2), do: "十"
  defp unit(3), do: "百"
  defp unit(4), do: "千"

  @doc "确保 money_map 含全部三面额键（缺省 0）"
  def normalize(money_map) when is_map(money_map) do
    Map.merge(%{"gold" => 0, "silver" => 0, "coin" => 0}, money_map)
  end

  # finance.c 里 `→value()` = 枚数 × 基础值；`amount -= value()` 用价值而非枚数
  defp amount_value(money_map, denom) do
    Map.get(money_map, denom, 0) * Map.fetch!(@denominations, denom)
  end
end

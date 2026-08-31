defmodule Kantele.Npc.Banker do
  @moduledoc """
  银行家行为（对应 `feature/banker.c` 银号存取汇兑）

  纯逻辑：不直接改角色状态，只在 `balance` + `money_map` 上做计算，返回
  结果或 `{:ok, new_balance, new_money_map}`。宿主负责 start_busy / 消息 /
  落盘。

  money_map 形如 `%{"gold" => g, "silver" => s, "coin" => c}`（见
  `Kantele.Economy.Money`）。
  """

  alias Kantele.Economy.Money

  @max_withdraw 10_000

  @doc "查余额（对应 do_check）：返回 {:empty} 或 {:balance, total}"
  def check(balance) do
    if is_integer(balance) and balance > 0, do: {:balance, balance}, else: {:empty}
  end

  @doc """
  兑换（对应 do_convert）：把 amount 个 from 面额换成 to 面额

  返回 `{:ok, new_money_map}` 或 `{:error, reason}`。
  """
  def convert(money_map, amount, from, to) do
    from_base = Money.denominations()[from]
    to_base = Money.denominations()[to]

    cond do
      is_nil(from_base) or is_nil(to_base) -> {:error, "没有这种货币"}
      from == to -> {:error, "你要换同一种货币？"}
      amount < 1 -> {:error, "你想白赚啊？"}
      Map.get(money_map, from, 0) < amount -> {:error, "带的#{from}不够"}
      true -> convert_ok(money_map, amount, from, to, from_base, to_base)
    end
  end

  defp convert_ok(money_map, amount, from, to, from_base, to_base) do
    # 从大面额换小面额时，不够整份的舍去
    amount =
      if from_base < to_base, do: amount - rem(amount, div(to_base, from_base)), else: amount

    if amount == 0,
      do: {:error, "不够换"},
      else: do_convert(money_map, amount, from, to, from_base, to_base)
  end

  defp do_convert(money_map, amount, from, to, from_base, to_base) do
    to_amount = div(amount * from_base, to_base)

    if from_base > to_base and div(from_base, to_base) * amount > 10_000 do
      {:error, "一下子拿不出这么多散钱"}
    else
      new_map =
        money_map
        |> Map.update!(from, &(&1 - amount))
        |> Map.update(to, to_amount, &(&1 + to_amount))
        |> Money.normalize()

      {:ok, new_map}
    end
  end

  @doc "存款（对应 do_deposit）：把 amount 个 what 面额存入 balance"
  def deposit(money_map, balance, amount, what) do
    base = Money.denominations()[what]

    cond do
      Map.get(money_map, what, 0) < amount ->
        {:error, "带的#{what}不够"}

      amount < 1 ->
        {:error, "你想存多少？"}

      true ->
        new_balance = (balance || 0) + base * amount
        new_map = money_map |> Map.update!(what, &(&1 - amount)) |> Money.normalize()
        {:ok, new_balance, new_map}
    end
  end

  @doc "取款（对应 do_withdraw）：从 balance 取出 amount 个 what 面额"
  def withdraw(money_map, balance, amount, what) do
    base = Money.denominations()[what]

    cond do
      amount < 1 ->
        {:error, "你想取多少钱？"}

      amount >= @max_withdraw ->
        {:error, "这么大数目本店没这么多零散现金"}

      is_nil(base) ->
        {:error, "你想取出什么钱？"}

      amount * base > (balance || 0) ->
        {:error, "你存的钱不够取"}

      true ->
        new_balance = (balance || 0) - amount * base
        new_map = money_map |> Map.update(what, amount, &(&1 + amount)) |> Money.normalize()
        {:ok, new_balance, new_map}
    end
  end

  @doc "转账（对应 do_transfer）：从 balance 扣一笔给他人 balance"
  def transfer(balance, amount, what) do
    base = Money.denominations()[what]

    cond do
      amount < 1 -> {:error, "你想转帐多少钱？"}
      amount > 10_000 -> {:error, "这么大数目有洗钱嫌疑"}
      is_nil(base) -> {:error, "你想转帐的单位是？"}
      amount * base > (balance || 0) -> {:error, "你存的钱不够转帐"}
      true -> {:ok, (balance || 0) - amount * base, amount * base}
    end
  end
end

defmodule Kantele.Character.BankCommand do
  @moduledoc """
  钱庄存取：`bank [check]` 查存款、`bank deposit|存 <数量> <面额>` 存款、
  `bank withdraw|取 <数量> <面额>` 取款

  用 `Kantele.Npc.Banker`（banker.c 移植）在「身上铜钱」与「钱庄存款」间划转：
  - 身上钱唯一存量是扁平铜钱 `meta.coins`，拆成面额 `Money.split/1` 后按
    `deposit/withdraw` 做分币逻辑
  - 存款/取款结果再以 `Money.total_value/1` 归并回扁平铜钱写回 meta
  - 存款余额 `meta.bank_coins`（运行态；暂不落盘，与 `quests` 一致）

  对照 LPC `feature/banker.c` 的 do_deposit / do_withdraw / do_check 展示层。
  """

  use Kalevala.Character.Command

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Economy.Money
  alias Kantele.Npc.Banker

  def run(conn, %{"rest" => rest}) do
    case String.split(String.trim(rest || "")) do
      [] -> show(conn)
      ["check" | _] -> show(conn)
      ["查询" | _] -> show(conn)
      [verb, amount, denom] when verb in ["deposit", "存"] -> deposit(conn, amount, denom)
      [verb, amount, denom] when verb in ["withdraw", "取"] -> withdraw(conn, amount, denom)
      [verb, amount, from, "to", to] when verb in ["convert", "兑换"] -> convert(conn, amount, from, to)
      [verb, amount, denom, "to", who] when verb in ["transfer", "转"] -> transfer(conn, amount, denom, who)
      _ -> usage(conn)
    end
  end

  def run(conn, _params), do: show(conn)

  @doc "查存款（对应 banker.c do_check；命令分发入口 arity 2）"
  def show(conn, _params), do: show(conn)

  @doc "查存款（对应 banker.c do_check）"
  def show(conn) do
    balance = PlayerMeta.bank_coins(conn.character.meta)
    on_hand = conn.character.meta.coins || 0

    text =
      "你在这家钱庄共存了#{Money.money_str(balance)}，" <>
        "身上带着#{Money.money_str(on_hand)}。\n"

    reply(conn, text)
  end

  @doc "存款（对应 banker.c do_deposit，把身上的钱存入钱庄）"
  def deposit(conn, amount_str, denom_str) do
    amount = parse_int(amount_str)
    denom = parse_denom(denom_str)

    if is_nil(denom) do
      reply(conn, "没有这种货币。\n")
    else
      meta = conn.character.meta
      money_map = Money.split(meta.coins || 0)
      balance = PlayerMeta.bank_coins(meta)

      case Banker.deposit(money_map, balance, amount, denom) do
        {:ok, new_balance, new_map} ->
          new_coins = Money.total_value(new_map)
          meta = %{meta | coins: new_coins} |> PlayerMeta.put_bank_coins(new_balance)
          character = Map.put(conn.character, :meta, meta)
          Records.save(character)

          text =
            "你存入了#{Money.money_str(denom_base(denom) * amount)}，" <>
              "户头里现在有#{Money.money_str(new_balance)}。\n"

          conn
          |> put_character(character)
          |> reply(text)

        {:error, reason} ->
          reply(conn, "#{friendly(reason)}\n")
      end
    end
  end

  @doc "取款（对应 banker.c do_withdraw，从钱庄取出）"
  def withdraw(conn, amount_str, denom_str) do
    amount = parse_int(amount_str)
    denom = parse_denom(denom_str)

    if is_nil(denom) do
      reply(conn, "没有这种货币。\n")
    else
      meta = conn.character.meta
      money_map = Money.split(meta.coins || 0)
      balance = PlayerMeta.bank_coins(meta)

      case Banker.withdraw(money_map, balance, amount, denom) do
        {:ok, new_balance, new_map} ->
          new_coins = Money.total_value(new_map)
          meta = %{meta | coins: new_coins} |> PlayerMeta.put_bank_coins(new_balance)
          character = Map.put(conn.character, :meta, meta)
          Records.save(character)

          text =
            "你取出了#{Money.money_str(denom_base(denom) * amount)}，" <>
              "户头里还剩#{Money.money_str(new_balance)}。\n"

          conn
          |> put_character(character)
          |> reply(text)

        {:error, reason} ->
          reply(conn, "#{friendly(reason)}\n")
      end
    end
  end

  @doc "货币兑换（对应 banker.c do_convert，把一种货币换成另一种）"
  def convert(conn, amount_str, from_denom_str, to_denom_str) do
    amount = parse_int(amount_str)
    from_denom = parse_denom(from_denom_str)
    to_denom = parse_denom(to_denom_str)

    if is_nil(from_denom) or is_nil(to_denom) do
      reply(conn, "没有这种货币。\n")
    else
      meta = conn.character.meta
      money_map = Money.split(meta.coins || 0)

      case Banker.convert(money_map, amount, from_denom, to_denom) do
        {:ok, new_map} ->
          new_coins = Money.total_value(new_map)
          meta = %{meta | coins: new_coins}
          character = Map.put(conn.character, :meta, meta)
          Records.save(character)

          from_value = denom_base(from_denom) * amount
          to_value = denom_base(to_denom) * amount

          text =
            "你把#{Money.money_str(from_value)}兑换成了#{Money.money_str(to_value)}。\n"

          conn
          |> put_character(character)
          |> reply(text)

        {:error, reason} ->
          reply(conn, "#{friendly(reason)}\n")
      end
    end
  end

  @doc "转账（对应 banker.c do_transfer，向另一玩家转账）"
  def transfer(conn, amount_str, denom_str, who) do
    amount = parse_int(amount_str)
    denom = parse_denom(denom_str)

    if is_nil(denom) do
      reply(conn, "没有这种货币。\n")
    else
      meta = conn.character.meta
      balance = PlayerMeta.bank_coins(meta)

      case Banker.transfer(balance, amount, denom) do
        {:ok, new_balance, value} ->
          meta = PlayerMeta.put_bank_coins(meta, new_balance)
          character = Map.put(conn.character, :meta, meta)
          Records.save(character)

          text =
            "你向 #{who} 转账了#{Money.money_str(value)}，" <>
              "户头里还剩#{Money.money_str(new_balance)}。\n"

          conn
          |> put_character(character)
          |> reply(text)

        {:error, reason} ->
          reply(conn, "#{friendly(reason)}\n")
      end
    end
  end

  defp usage(conn) do
    reply(conn, "钱庄用法：bank 查余额；bank deposit|存 <数量> <金|银|铜>；bank withdraw|取 <数量> <金|银|铜>；bank convert|兑换 <数量> <金|银|铜> to <金|银|铜>；bank transfer|转 <数量> <金|银|铜> to <玩家>\n")
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp parse_int(str) do
    case Integer.parse(str || "") do
      {int, _} when int >= 0 -> int
      _ -> 0
    end
  end

  defp parse_denom(d) do
    case d do
      "gold" -> "gold"
      "金" -> "gold"
      "silver" -> "silver"
      "银" -> "silver"
      "coin" -> "coin"
      "铜" -> "coin"
      _ -> nil
    end
  end

  defp denom_base(denom), do: Map.get(Money.denominations(), denom, 0)

  # Banker 返回的 reason 是 LPC 原文，域名用英文面额名；这里换成玩家向中文
  defp friendly(reason) do
    Map.get(
      %{
        "带的gold不够" => "你身上带的黄金不够。",
        "带的silver不够" => "你身上带的白银不够。",
        "带的coin不够" => "你身上带的铜钱不够。",
        "你想存多少？" => "你想存多少钱？",
        "你想取多少钱？" => "你想取多少钱？",
        "这么大数目本店没这么多零散现金" => "这么大数目本店没这么多零散现金。",
        "你存的钱不够取" => "你存的钱不够取。",
        "没有这种货币" => "没有这种货币。"
      },
      reason,
      String.replace_prefix(reason, "带的", "你身上带的")
    )
  end
end

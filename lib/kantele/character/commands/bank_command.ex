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
      [] ->
        show(conn)

      ["check" | _] ->
        show(conn)

      ["查询" | _] ->
        show(conn)

      [verb, amount, denom] when verb in ["deposit", "存"] ->
        deposit(conn, amount, denom)

      [verb, amount, denom] when verb in ["withdraw", "取"] ->
        withdraw(conn, amount, denom)

      [verb, amount, from, "to", to] when verb in ["convert", "兑换"] ->
        convert(conn, amount, from, to)

      [verb, amount, denom, "to", who] when verb in ["transfer", "转"] ->
        transfer(conn, amount, denom, who)

      _ ->
        usage(conn)
    end
  end

  def run(conn, _params), do: show(conn)

  # ---- LPC 顶层动词别名 ----
  #
  # LPC 的银行 NPC 是把子命令当**独立顶层动词**注册的：
  #   add_action("do_deposit", "deposit");  add_action("do_deposit", "cun");
  #   add_action("do_withdraw", "withdraw"); add_action("do_withdraw", "qu");
  #   add_action("do_convert", "convert");   add_action("do_convert", "duihuan");
  #   add_action("do_check", "chazhang");    add_action("do_transfer", "zhuan"/"transfer");
  # 玩家直接输 `cun 10 银`，而不是 `bank 存 10 银`。
  #
  # 参数格式与 banker.c 完全一致（`<数量> <货币单位>` / `<数量> <from> to <to>`），
  # 所以这里只做一层「拆词 → 转调既有实现」的适配，不复制任何存取逻辑。
  # 提示文案沿用 LPC 的 notify_fail 原文。

  # 带参形式（router 的 text/2 要求 min: 1，所以裸动词会走下面的分支）
  def cun(conn, %{"rest" => rest}), do: deposit_alias(conn, rest)
  def deposit_cmd(conn, %{"rest" => rest}), do: deposit_alias(conn, rest)
  def qu(conn, %{"rest" => rest}), do: withdraw_alias(conn, rest)
  def withdraw_cmd(conn, %{"rest" => rest}), do: withdraw_alias(conn, rest)
  def duihuan(conn, %{"rest" => rest}), do: convert_alias(conn, rest)
  def convert_cmd(conn, %{"rest" => rest}), do: convert_alias(conn, rest)
  def zhuan(conn, %{"rest" => rest}), do: transfer_alias(conn, rest)
  def transfer_cmd(conn, %{"rest" => rest}), do: transfer_alias(conn, rest)

  # 裸动词：LPC 这里走 notify_fail 打用法，照抄。
  # 必须用**不同的函数名**：router 的 parse 宏按 `parsep_<verb>_<fun>` 生成函数，
  # 同 verb 同 fun 注册两次会因默认参数重复定义而编译失败。
  def cun_bare(conn, _params), do: deposit_alias(conn, nil)
  def deposit_bare(conn, _params), do: deposit_alias(conn, nil)
  def qu_bare(conn, _params), do: withdraw_alias(conn, nil)
  def withdraw_bare(conn, _params), do: withdraw_alias(conn, nil)
  def convert_bare(conn, _params), do: convert_alias(conn, nil)
  def duihuan_bare(conn, _params), do: convert_alias(conn, nil)
  def transfer_bare(conn, _params), do: transfer_alias(conn, nil)
  def zhuan_bare(conn, _params), do: transfer_alias(conn, nil)

  @doc "查帐（LPC do_check 的顶层动词 `chazhang`）"
  def chazhang(conn, _params), do: show(conn)

  defp deposit_alias(conn, rest) do
    case words(rest) do
      [amount, denom] -> deposit(conn, amount, denom)
      _ -> reply(conn, "命令格式：deposit|cun <数量> <货币单位>\n")
    end
  end

  defp withdraw_alias(conn, rest) do
    case words(rest) do
      [amount, denom] -> withdraw(conn, amount, denom)
      _ -> reply(conn, "命令格式：withdraw|qu <数量> <货币单位>\n")
    end
  end

  defp convert_alias(conn, rest) do
    case words(rest) do
      [amount, from, "to", to] -> convert(conn, amount, from, to)
      [amount, from, "成", to] -> convert(conn, amount, from, to)
      _ -> reply(conn, "命令格式：convert|duihuan <数量> <货币单位> to <新货币单位>\n")
    end
  end

  defp transfer_alias(conn, rest) do
    case words(rest) do
      [amount, denom, "to", who] -> transfer(conn, amount, denom, who)
      [amount, denom, "给", who] -> transfer(conn, amount, denom, who)
      _ -> reply(conn, "命令格式：transfer|zhuan <数量> <货币单位> to <某人>\n")
    end
  end

  defp words(rest), do: String.split(String.trim(rest || ""))

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

          # 文案是「源面额枚数 + 源单位」→「目标面额枚数 + 目标单位」（LPC do_convert）。
          # 不能拿总价值去 `money_str/1`：那样 5 两白银换 500 文会渲染成
          # 「五两白银兑换成了五两白银」（R11）。成交枚数由 `Banker` 统一给出，
          # 与 `convert/4` 的取整逻辑共用，不会再漂移。
          {from_amount, to_amount} = Banker.convert_quote(amount, from_denom, to_denom)

          text =
            "你把#{Money.denom_str(from_amount, from_denom)}兑换成了" <>
              "#{Money.denom_str(to_amount, to_denom)}。\n"

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
    reply(
      conn,
      "钱庄用法：bank 查余额；bank deposit|存 <数量> <金|银|铜>；bank withdraw|取 <数量> <金|银|铜>；bank convert|兑换 <数量> <金|银|铜> to <金|银|铜>；bank transfer|转 <数量> <金|银|铜> to <玩家>\n"
    )
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

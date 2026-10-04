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

  # LPC dealer.c:360 `MAX_ITEM_CARRIED` —— 玩家身上未装备物品数的上限
  @max_item_carried 100

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
    stackable? = stackable?(item)

    cond do
      amount < 1 ->
        {:reject, "亏你想的出来，有这样卖东西的吗？"}

      not stackable? and amount > 1 ->
        {:reject, "这种东西不能拆开来卖。"}

      stackable? and amount > stack_size(item) ->
        {:reject, "你身上没有这么多。"}

      Map.get(item, :money_id) ->
        {:reject, "你想卖「钱」？"}

      Map.get(item, :is_character?, false) ->
        {:reject, "我这里做正经生意，不贩卖这些！"}

      Map.get(item, :no_drop?, false) or no_sell?(item) ->
        {:reject, no_sell_reason(item)}

      # LPC dealer.c:160 —— 店小二不收自己店里的货
      is_vendor_good?(item) ->
        {:reject, "我卖给你好不好？"}

      Map.get(item, :food_supply?) ->
        {:reject, "剩菜剩饭留给您自己用吧。"}

      Map.get(item, :shaolin?) ->
        {:reject, "小的胆子很小，可不敢买少林庙产。"}

      Map.get(item, :mingjiao?) ->
        {:reject, "小的只有一个脑袋，可不敢买魔教的东西。"}

      true ->
        {:ok, sell_value(item, amount, stackable?)}
    end
  end

  @doc """
  该物品是否**可叠加**（LPC `query_amount()` 非 0）。

  LPC 里 `query_amount()` 对「不可叠加的物品」返回 **0**，
  `dealer.c` 就是靠这个区分：

      max_count = ob->query_amount();
      if (! max_count) { // not combined object
          if (amount > 1) { write("这种东西不能拆开来卖。"); return 1; }
          max_count = 1;
      }

  注意别写成 `Map.get(item, :amount, 1) < 1` —— 默认值 1 让 `< 1`
  永远不成立，那两条拒绝分支就成了死代码（`:amount` 缺失才是不可叠加）。
  """
  def stackable?(item) do
    case Map.get(item, :amount) do
      n when is_integer(n) and n > 0 -> true
      _ -> false
    end
  end

  defp stack_size(item), do: Map.get(item, :amount, 1)

  # LPC dealer.c:160 `if (is_vendor_good(arg) != "")` —— 卖回店里的货要被拒。
  # 调用方（派发层）会把自己的 vendor_goods 传进来；这里只判 item 自身是否
  # 属于该店的目录，命中即拒。
  defp is_vendor_good?(item) do
    case Map.get(item, :vendor_good) do
      true -> true
      _ -> false
    end
  end

  @doc """
`do_buy` 的前置检查（LPC `dealer.c:337-364`）。

LPC 在算价**之前**有 4 道检查，`do_buy/4` 只保留了「一次最多 100 件」，
其余 3 道在这里补上。返回 `{:ok, nil}` 表示放行。

- `carried_count`：玩家身上**未装备**的物品数，对应 LPC 的 `MAX_ITEM_CARRIED`
- `opts[:current_room]` / `opts[:start_room]`：跑偏自愈用
- `opts[:busy?]`：上一次交易的 1 秒冷却

## 跑偏自愈（LPC:338-357）

NPC 不卖「背包里带着的货」（`carried_goods`）时，如果自己不在 `startroom`
里了，就会说一句「咦？我怎么跑到这儿来了？」然后**要么传送回去、要么自杀**。
这是防 NPC 被拖走 / 走丢后的自愈机制，和 `walker` 的 15 分钟自杀同类。
"""
  def check_buy_preconditions(opts) do
    carried = Map.get(opts, :carried_count, 0)
    max_carried = Map.get(opts, :max_item_carried, @max_item_carried)
    start_room = Map.get(opts, :start_room)
    current_room = Map.get(opts, :current_room)
    carried_goods? = Map.get(opts, :carried_goods?, false)

    cond do
      # LPC:338 未卖 carried_goods 且不在 startroom
      not carried_goods? and is_binary(start_room) and current_room != nil and
          current_room != start_room ->
        {:recover, recovery_action(start_room, Map.get(opts, :still_listed?, true))}

      # LPC:359 身上东西太多
      carried >= max_carried ->
        {:reject, "你身上的东西太多了，先处理一下再买东西吧。"}

      # LPC:424 上一次交易还没结束（1 秒冷却）
      Map.get(opts, :busy?, false) ->
        {:reject, "没看见我这儿正忙着么？"}

      true ->
        {:ok, nil}
    end
  end

  # LPC dealer.c:344-355：还在 startroom 的对象列表里就传送回去，否则自杀
  defp recovery_action(start_room, still_listed?) do
    action = if still_listed?, do: :teleport_home, else: :despawn
    %{action: action, room_id: start_room, message: "咦？我怎么跑到这儿来了？"}
  end

  @doc "LPC `destruct_it/1`：延迟销毁临时造出来的物品（防泄漏）"
  # LPC 用 `call_out("destruct_it", 0, ob)`；这里只描述该做什么，
  # 真正的定时销毁由派发层用 Process.send_after 落地。
  def destruct_it_plan(item_id) do
    %{action: :destroy_temp_item, item_id: item_id}
  end

  @doc "LPC `enough_rest/0`：1 秒后清掉 `busy` 标记（交易冷却）"
  def enough_rest_plan, do: %{action: :clear_busy, delay_ms: 1000}

  @doc """
  LPC `reset/0`：库存清理 —— 超过 100 件或单件重量 >= 1000000 就销毁。

  返回要销毁的 item_id 列表；`reset` 返回 `:ok` 表示清完了。
  """
  def reset_plan(inventory, opts \\ %{}) do
    {max_count, max_weight} =
      if is_list(opts) do
        {Keyword.get(opts, :max_count, 100), Keyword.get(opts, :max_weight, 1_000_000)}
      else
        {Map.get(opts, :max_count, 100), Map.get(opts, :max_weight, 1_000_000)}
      end

    {_keep, drop} =
      Enum.split_with(inventory, fn item ->
        Map.get(item, :count, 1) < max_count and Map.get(item, :weight, 0) < max_weight
      end)

    case drop do
      [] -> :ok
      _ -> Enum.map(drop, &Map.get(&1, :id))
    end
  end

  @doc "购买价计算（do_buy/3 价格部分）"
  # val_factor: 现金货按库存价（当前手里现货 12，目录补货 10），与 dealer.c 一致
  def do_buy(item, amount, goods, opts \\ %{}) do
    val_factor = Map.get(opts, :val_factor, 10)

    cond do
not is_integer(amount) or amount < 1 or amount > 100 ->
        {:reject, "慢慢来，一次最多买一百件。"}

      Map.get(item, :money_id) ->
        {:reject, "你要买钱？有意思！"}

      # LPC dealer.c:455 `if (amount > 1 && ! ob->query_amount())`
      # 即「不可叠加的物品不能一次买多个」。别用 `Map.get(item, :amount, 1) < 1`
      # —— 默认 1 让条件恒假，这条分支曾经是死代码。
      amount > 1 and not stackable?(item) ->
        {:reject, "只能一个一个的买。"}

      true ->
        do_buy_value(item, amount, goods, val_factor, opts)
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

  defp sell_value(item, amount, stackable?) do
    # LPC dealer.c:184 `if (max_count > 1) value = base_value * amount; else value = value;`
    # 注意条件是 `max_count > 1`，不是「可叠加」—— 只有**确实叠了 2 件以上**
    # 才按 base_value 算。
    value =
      if stackable? and stack_size(item) > 1,
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

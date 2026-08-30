defmodule Kantele.Character.BackpackCommand do
  @moduledoc """
  背包/仓库命令（对应 `feature/user_storage.c` 的 `store/take/背包`）：

  - `store <物品>`：存入一件
  - `store <数量> <物品>`：存入多件同名物品
  - `store all`：存入所有可存放物品
  - `take <编号> <数量>`：按编号+数量取回
  - `背包`（无参数）：查看背包

  规则（与 LPC 一致）：
  - 需持有 `meta.storage_bag=N` 的背包容器才解锁（否则"你还没有背包呢。"）
  - 忙碌/战斗中拒绝存取
  - 容量 = `Backpack.capacity(combat_exp, extra)`，extra 为身上各背包容器 storage_bag 之和
  - 不可存放：装备中、食物、液体、钱币、不可克隆/`no_clone`/`no_put`/`no_store` 物品
  - 每件物品实例计 1 数量；`store all` 跳过背包容器本身
  """

  use Kalevala.Character.Command

  import Kalevala.Character.Conn

  alias Kalevala.Verb
  alias Kalevala.Verb.Context
  alias Kalevala.World.Item
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Item.Backpack
  alias Kantele.World.Items

  # ---- store ----

  def store(conn, %{"rest" => rest}), do: store(conn, rest)

  def store(conn, rest) when is_binary(rest) do
    cond do
      not unlock?(conn) ->
        fail(conn, "你还没有背包呢。\n")

      Combat.busy?(conn.character.meta.combat) ->
        fail(conn, "你正忙着呢！\n")

      Combat.fighting?(conn.character.meta.combat) ->
        fail(conn, "你正在战斗中呢。\n")

      true ->
        do_store(conn, String.trim(rest || ""))
    end
  end

  def store_bare(conn, _params), do: store(conn, "")

  # ---- take ----

  def take(conn, %{"rest" => rest}), do: take(conn, rest)

  def take(conn, rest) when is_binary(rest) do
    cond do
      not unlock?(conn) ->
        fail(conn, "你还没有背包呢。\n")

      Combat.busy?(conn.character.meta.combat) ->
        fail(conn, "你正忙着呢。\n")

      Combat.fighting?(conn.character.meta.combat) ->
        fail(conn, "你正在战斗中呢。\n")

      true ->
        do_take(conn, String.trim(rest || ""))
    end
  end

  def take_bare(conn, _params), do: take(conn, "")

  # ---- 背包查看 ----

  def list(conn, _params) do
    case unlock?(conn) do
      false ->
        fail(conn, "你还没有背包呢。\n")

      true ->
        case PlayerMeta.bag(conn.character.meta) do
          [] ->
            conn
            |> render(CommandView, "text", %{text: "你的背包里没有存放任何物品。\n"})
            |> prompt(CommandView, "prompt", %{})

          bag ->
            {_has, extra} = bag_state(conn)

            text =
              Backpack.list_bag(bag) <>
                "已用 #{length(bag)}/#{Backpack.capacity(combat_exp(conn), extra)} 格。\n"

            conn
            |> render(CommandView, "text", %{text: text})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  # ---- store 分派 ----

  defp do_store(conn, ""), do: fail(conn, "你要存放什么东西？\n")

  defp do_store(conn, "all"), do: store_all(conn)

  defp do_store(conn, rest) do
    case parse_amount_item(rest) do
      {:ok, amount, _item_name} when amount < 1 ->
        fail(conn, "存东西的数量至少是一个。\n")

      {:ok, amount, item_name} ->
        store_named(conn, item_name, amount)

      :error ->
        store_named(conn, rest, 1)
    end
  end

  # 按名字找实例（≤amount 件），逐个逐条校验后存入
  defp store_named(conn, item_name, amount) do
    cond do
      full?(conn) ->
        fail(conn, capacity_full_text(conn))

      true ->
        case find_instances(conn.character.inventory, item_name) do
          [] ->
            fail(conn, "你身上没有这样东西。\n")

          instances ->
            collect = Enum.take(instances, amount)

            if length(collect) < amount do
              item = safe_item(List.first(instances))
              fail(conn, "你没有那么多的#{item && item.name || "东西"}。\n")
            else
              store_each(conn, collect)
            end
        end
    end
  end

  # store all：跳过背包容器本身，存全部可存放物品
  defp store_all(conn) do
    eligible =
      Enum.filter(conn.character.inventory, fn instance ->
        item = safe_item(instance)
        item != nil and not is_bag?(item) and storable?(conn, item)
      end)

    cond do
      full?(conn) ->
        fail(conn, capacity_full_text(conn))

      eligible == [] ->
        fail(conn, "你身上没有任何可以保存的物品。\n")

      length(eligible) > 100 ->
        fail(conn, "你身上的物品太多了，很容易搞混，你还是一个一个存吧。\n")

      true ->
        store_each(conn, eligible)
    end
  end

  # 完整可存校验（供 store all 预筛；与 store_check 一致）
  defp storable?(conn, item), do: match?(:ok, store_check(conn, item))

  # 逐条执行 store_item 语义：任一失败则全部回滚并提示
  defp store_each(conn, instances) do
    bag = PlayerMeta.bag(conn.character.meta)

    case Enum.reduce_while(instances, {:ok, bag}, fn instance, {:ok, acc_bag} ->
           item = safe_item(instance)

           case store_check(conn, item) do
             :ok -> {:cont, {:ok, do_store_item(acc_bag, instance, item)}}
             {:error, msg} -> {:halt, {:error, msg}}
           end
         end) do
      {:error, msg} ->
        fail(conn, msg)

      {:ok, new_bag} ->
        removed_ids = Enum.map(instances, & &1.id)
        inventory = Enum.reject(conn.character.inventory, &(&1.id in removed_ids))
        name = item_name_of(instances)

        character = %{conn.character | inventory: inventory}
        character = %{character | meta: PlayerMeta.put_bag(character.meta, new_bag)}

        text =
          case length(instances) do
            1 -> "你把#{name}存到背包里。\n"
            n -> "你把#{n}个#{name}存到背包里。\n"
          end

        persist(conn, character, text)
    end
  end

  # store_item 的可存校验（LPC store_item/1）
  defp store_check(_conn, nil), do: {:error, reason_unknown_item()}

  defp store_check(conn, item) do
    cond do
      money?(item) ->
        {:error, "存钱请找钱庄老板存(deposit)。\n"}

      food?(item) ->
        {:error, "食物饮水存背包里会变质的。\n"}

      liquid?(item) ->
        {:error, "食物饮水存背包里会变质的。\n"}

      equipped_item?(conn, item) ->
        {:error, "#{item.name}必须先脱离装备才能存放。\n"}

      store_ok?(item) == false ->
        {:error, "背包不保存#{item.name}，请你自己妥善处理。\n"}

      true ->
        :ok
    end
  end

  # 与 LPC store_item 一致：同 file+id+name 合并数量，否则新增一条
  defp do_store_item(bag, instance, item) do
    entry = %{file: instance.item_id, name: item.name, id: item.id}

    case Backpack.store(bag, entry, 1) do
      {:ok, new_bag, _} -> new_bag
    end
  end

  defp money?(_item), do: false

  defp food?(item), do: item.meta.food != nil

  defp liquid?(item) do
    Verb.has_matching_verb?(item.verbs, :drink, %Context{location: "inventory/self"})
  end

  defp equipped_item?(conn, item) do
    character = conn.private.update_character || conn.character

    character.meta.combat.equipped
    |> Enum.any?(fn {_slot, snap} -> Map.get(snap, :name) == item.name end)
  end

  # 可被背包复制的物品才可存放（LPC 无 clone 动词/不可克隆物品丢弃）
  defp store_ok?(item) do
    cond do
      not cloneable?(item) -> false
      no_store?(item) -> false
      true -> true
    end
  end

  defp cloneable?(item) do
    Verb.has_matching_verb?(item.verbs, :clone, %Context{location: "inventory/self"})
  end

  defp no_store?(item) do
    Map.get(item.meta, :no_clone) ||
      Map.get(item.meta, :no_put) ||
      Map.get(item.meta, :no_store)
  end

  defp is_bag?(item), do: item.meta.storage_bag != nil and item.meta.storage_bag != 0

  # ---- take 分派 ----

  defp do_take(conn, rest) do
    case parse_index_amount(rest) do
      {:error, msg} ->
        fail(conn, msg)

      {:ok, _index, amount} when amount < 1 or amount > 10_000 ->
        fail(conn, "每次取物品的数量不得小于 1 同时也不能大于 10000 。\n")

      {:ok, index, amount} ->
        execute_take(conn, index, amount)
    end
  end

  defp execute_take(conn, index, amount) do
    case Backpack.take(PlayerMeta.bag(conn.character.meta), index, amount) do
      {:error, msg} ->
        fail(conn, msg)

      {:ok, entry, new_bag} ->
        grant_instances(conn, entry, new_bag)
    end
  end

  # 按存档 file 重建实例并放回背包
  defp grant_instances(conn, entry, new_bag) do
    case Items.get(entry.file) do
      {:ok, _item} ->
        now = DateTime.utc_now()

        instances =
          for _ <- 1..entry.amount do
            %Item.Instance{
              id: Item.Instance.generate_id(),
              item_id: entry.file,
              created_at: now
            }
          end

        character = %{conn.character | inventory: instances ++ conn.character.inventory}
        character = %{character | meta: PlayerMeta.put_bag(character.meta, new_bag)}

        take_text =
          case entry.amount do
            1 -> "你从背包里取出#{entry.name}。\n"
            n -> "你从背包里取出#{n}个#{entry.name}。\n"
          end

        persist(conn, character, take_text)

      {:error, _reason} ->
        # 模板已失效：清除该格并落盘
        cleared = Enum.reject(new_bag, &(&1.file == entry.file))
        character = %{conn.character | meta: PlayerMeta.put_bag(conn.character.meta, cleared)}
        persist(conn, character, "无法取出该物品，系统自动清除之。\n")
    end
  end

  # ---- 参数解析 ----

  defp parse_amount_item(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [amount_str, item_name] ->
        case Integer.parse(amount_str) do
          {amount, ""} -> {:ok, amount, item_name}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_index_amount(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [index_str] ->
        case Integer.parse(index_str) do
          {index, ""} when index >= 1 -> {:ok, index, 1}
          _ -> {:error, "格式错误，请用 take 编号 数量 来取回物品。\n"}
        end

      [index_str, amount_str] ->
        with {index, ""} <- Integer.parse(index_str),
             {amount, ""} <- Integer.parse(amount_str) do
          if index >= 1, do: {:ok, index, amount}, else: {:error, "你要取第几号物品？\n"}
        else
          _ -> {:error, "格式错误，请用 take 编号 数量 来取回物品。\n"}
        end

      _ ->
        {:error, "格式错误，请用 take 编号 数量 来取回物品。\n"}
    end
  end

  # ---- 通用 ----

  # 是否持有背包容器（item.meta.storage_bag > 0 生效；LPC query("storage_bag")）
  defp unlock?(conn) do
    {has, _extra} = bag_state(conn)
    has
  end

  # {是否解锁, storage_bag 扩展格之和}
  defp bag_state(conn) do
    Enum.reduce(conn.character.inventory, {false, 0}, fn instance, {found, acc} ->
      item = safe_item(instance)

      case item && item.meta.storage_bag do
        n when is_integer(n) and n > 0 -> {true, acc + n}
        _ -> {found, acc}
      end
    end)
  end

  defp full?(conn) do
    bag = PlayerMeta.bag(conn.character.meta)
    {_has, extra} = bag_state(conn)
    length(bag) >= Backpack.capacity(combat_exp(conn), extra)
  end

  defp capacity_full_text(conn) do
    {_has, extra} = bag_state(conn)
    "你背包的 #{Backpack.capacity(combat_exp(conn), extra)} 个储藏空间全被使用了，请整理一下吧。\n"
  end

  defp combat_exp(conn), do: conn.character.meta.stats.combat_exp

  defp find_instances(inventory, item_name) do
    Enum.filter(inventory, fn instance ->
      item = safe_item(instance)
      item != nil && (instance.id == item_name || item.callback_module.matches?(item, item_name))
    end)
  end

  defp item_name_of(instances) do
    case List.first(instances) do
      nil ->
        "东西"

      instance ->
        case safe_item(instance) do
          nil -> "东西"
          item -> item.name
        end
    end
  end

  defp safe_item(instance) do
    Items.get!(instance.item_id)
  rescue
    _ -> nil
  end

  defp reason_unknown_item, do: "背包不能保存这件东西。\n"

  defp persist(conn, character, text) do
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
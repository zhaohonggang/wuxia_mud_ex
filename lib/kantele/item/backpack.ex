defmodule Kantele.Item.Backpack do
  @moduledoc """
  玩家背包/仓库（对应 `feature/user_storage.c`）

  纯容器：`bag` 为 `%{file, name, id, amount}` 结构列表。
  - `store/2`: 存入（已存在同 `file/id/name` 则合并数量）
  - `take/3`: 取出按编号+数量（越界/超量钳制）
  - `list_bag/1`: 生成显示行
  - `serialize/1` / `deserialize/1`: 存档/恢复（LPC save_depot/restore_depot）

  宿主命令层负责：storage_bag 判定、忙碌/战斗拦截、物品实体验证。
  """

  @doc "背包格数计算（LPC: (combat_exp*10)^(1/3)+1)/10，clamp 9..99，再加扩展格）"
  def capacity(combat_exp, extra \\ 0) do
    n = div(trunc(:math.pow(combat_exp * 10, 1.0 / 3)) + 1, 10)

    n = if n < 9, do: 9, else: n
    n = if n > 99, do: 99, else: n
    n + extra
  end

  @doc "是否已有存储判定（进入背包前）"
  def storage_bag?(meta), do: Map.get(meta, :storage_bag) != nil

  @doc "store_item：存入（返回 {新bag, 存/并 结果）：合并或新增"
  def store(bag, %{file: file, name: name, id: id} = item, amount) do
    idx = Enum.find_index(bag, fn e -> e.file == file and e.id == id and e.name == name end)

    cond do
      idx != nil ->
        old = Enum.at(bag, idx)
        {:ok, List.replace_at(bag, idx, %{old | amount: old.amount + amount}), :merged}

      true ->
        {:ok, bag ++ [%{file: file, name: name, id: id, amount: amount}], :added}
    end
  end

  @doc "do_take：按 1-based 编号+数量取回。返回 `{:ok, 取出的描述, 新bag}` 或 {:error,msg}"
  def take(bag, index, amount) do
    cond do
      bag == [] or bag == nil -> {:error, "你的背包里没有存放任何物品。"}
      index < 1 -> {:error, "你要取第几号物品？"}
      index > length(bag) -> {:error, "你的背包里没有存放这项物品。"}
      true -> do_take(bag, index - 1, amount)
    end
  end

  @doc "list_bag 显示文本"
  def list_bag(bag) do
    lines =
      Enum.with_index(bag, 1)
      |> Enum.map(fn {e, i} ->
        "[#{String.pad_leading(to_string(i), 2)}]  " <>
          String.pad_trailing("#{e.name}(#{e.id})", 36) <> "      " <> to_string(e.amount)
      end)

    Enum.join([
      "\n你的背包里存放的物品有：\n编号  物品                                      数量\n",
      "----------------------------------------------------\n",
      Enum.join(lines, "\n"),
      "\n----------------------------------------------------\n"
    ])
  end

  @doc "存档（LPC save_depot）：按 item0/item1... 编号序列化"
  def serialize(bag) do
    bag
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {e, i}, acc ->
      Map.put(acc, "item#{i}", %{
        "name" => e.name,
        "id" => e.id,
        "file" => e.file,
        "amount" => e.amount
      })
    end)
  end

  @doc "恢复（LPC restore_depot）"
  def deserialize(data) when is_map(data) do
    data
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map(fn {_k, v} ->
      %{file: v["file"], name: v["name"], id: v["id"], amount: v["amount"]}
    end)
  end

  def deserialize(_), do: []

  defp do_take(bag, idx, amount) do
    entry = Enum.at(bag, idx)
    take_amount = if amount > entry.amount, do: entry.amount, else: amount

    new_bag =
      if take_amount >= entry.amount do
        List.delete_at(bag, idx)
      else
        List.replace_at(bag, idx, %{entry | amount: entry.amount - take_amount})
      end

    {:ok, %{entry | amount: take_amount}, new_bag}
  end
end

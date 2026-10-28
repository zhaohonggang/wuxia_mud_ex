defmodule Kantele.Character.DiscardCommand do
  @moduledoc """
  锻造退款：`discard <物品>`

  对应 LPC ganjiang.c 的 `do_discard`：玩家把自己锻造的自制物品交回干将，
  按估价的 80% 退还黄金。

  门控（对应 LPC）：
    - 物品在玩家背包中
    - item.meta.item_make == true     （仅自制物品可退）
    - item.meta.owner_id == 玩家 id   （仅本人锻造的可退）

  退款金额（计划 §4 S4）：
    - n = (value * 8 / 10 + 9999) / 10000  两黄金
      （value 存单位为文，向上取整到整两）
    - 折算为铜钱（n * 10000）入账 meta.coins

  超时：驱动不自动触发退款（计划 §6 偏差），玩家主动 `discard` 或重新
  `give` 材料取回，故本命令不设定时器。
  乾坤袋：qiankun stone 分支属锻造受理流程（S1b/S4），不在 discard 退款
  范围内（计划 §7 标记待定，不影响主线）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Item
  alias Kantele.World.Items

  def run(conn, %{"item_name" => raw}) do
    name = String.trim(raw || "")

    cond do
      name == "" ->
        fail(conn, "你想退回什么？\n")

      true ->
        do_discard(conn, name)
    end
  end

  def run(conn, %{}), do: fail(conn, "你想退回什么？\n")

  defp do_discard(conn, name) do
    character = conn.character

    case find_item(character, name) do
      nil ->
        fail(conn, "你身上没有#{name}这种东西。\n")

      instance ->
        item = Items.get!(instance.item_id)
        meta = item.meta

        cond do
          not meta.item_make ->
            fail(conn, "#{item.name}不是自制物品，无法退款。\n")

          meta.owner_id != character.id ->
            fail(conn, "#{item.name}不是你锻造的，无法退款。\n")

          true ->
            value = meta.value || 0
            refund_gold = div(div(value * 8, 10) + 9999, 10_000)
            refund_coins = refund_gold * 10_000

            inventory =
              Enum.reject(character.inventory, fn inst -> inst.id == instance.id end)

            coins = (character.meta.coins || 0) + refund_coins
            new_character =
              %{character | inventory: inventory}
              |> Map.put(:meta, Map.put(character.meta, :coins, coins))

            Records.save(new_character)

            conn
            |> put_character(new_character)
            |> render(CommandView, "text", %{
              text: "你将#{item.name}交回干将，退还#{refund_gold}两黄金。\n"
            })
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp find_item(character, name) do
    Enum.find(character.inventory, fn inst ->
      item = Items.get!(inst.item_id)
      item.id == name or Item.matches?(item, name)
    end)
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

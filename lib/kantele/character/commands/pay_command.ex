defmodule Kantele.Character.PayCommand do
  @moduledoc """
  付款命令：`pay <数量> <面额> to <目标>` / `pay <目标> <数量> <面额>`

  主要用于在客店付房租给店小二（如 `pay xiaoer 100 铜`）。
  货币直接从 `meta.coins`（扁平铜钱）扣除，不走背包物品实例，
  因此不依赖 `give` 命令或世界数据中的货币物品定义。

  对照 LPC `cmds/std/pay.c` 的 do_pay + 客店 rent_paid 门控。
  """

  use Kalevala.Character.Command

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Economy.Money
  alias Kantele.NPC.Xiaoer

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    case parse_args(rest) do
      {:error, msg} ->
        conn
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})

      {:ok, target, amount, denom} ->
        do_pay(conn, target, amount, denom)
    end
  end

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "你要付给谁多少钱？用法：pay <目标> <数量> <金|银|铜>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 参数解析 ----

  # pay <目标> <数量> <面额>  （中文习惯：先目标）
  # pay <数量> <面额> to <目标>  （英文习惯）
  defp parse_args(rest) do
    cond do
      rest == "" ->
        {:error, "你要付给谁多少钱？\n"}

      String.contains?(rest, " to ") ->
        parse_pay_to(rest)

      true ->
        parse_target_first(rest)
    end
  end

  defp parse_pay_to(rest) do
    [amount_part, target] = String.split(rest, " to ", parts: 2)

    target = String.trim(target)
    if target == "" do
      {:error, "你要付给谁？\n"}
    else
      case parse_amount_denom(String.trim(amount_part)) do
        {:ok, amount, denom} -> {:ok, target, amount, denom}
        {:error, msg} -> {:error, msg}
      end
    end
  end

  defp parse_target_first(rest) do
    case String.split(rest, ~r/\s+/, parts: 3) do
      [target, amount_str, denom_str] ->
        case parse_amount_denom(amount_str <> " " <> denom_str) do
          {:ok, amount, denom} -> {:ok, target, amount, denom}
          {:error, msg} -> {:error, msg}
        end

      _ ->
        {:error, "用法：pay <目标> <数量> <金|银|铜>\n"}
    end
  end

  defp parse_amount_denom(spec) do
    case String.split(spec, ~r/\s+/) do
      [amount_str, denom_str] ->
        case Integer.parse(amount_str) do
          {amount, ""} when amount > 0 ->
            case parse_denom(denom_str) do
              {:ok, denom} -> {:ok, amount, denom}
              :error -> {:error, "没有这种货币。\n"}
            end
          _ ->
            {:error, "金额必须是正整数。\n"}
        end

      _ ->
        {:error, "金额格式错误。\n"}
    end
  end

  defp parse_denom(denom) do
    case denom do
      "gold" -> {:ok, "gold"}
      "金" -> {:ok, "gold"}
      "silver" -> {:ok, "silver"}
      "银" -> {:ok, "silver"}
      "coin" -> {:ok, "coin"}
      "铜" -> {:ok, "coin"}
      _ -> :error
    end
  end

  # ---- 付款执行 ----

  defp do_pay(conn, target, amount, denom) do
    base = Map.get(Money.denominations(), denom, 0)
    total = amount * base

    # 在当前房间找目标 NPC
    target_npc = find_npc_in_room(conn, target)

    cond do
      is_nil(target_npc) ->
        conn
        |> render(CommandView, "text", %{text: "这里没有这个人。\n"})
        |> prompt(CommandView, "prompt", %{})

      not Xiaoer.is_xiaoer?(target_npc) ->
        conn
        |> render(CommandView, "text", %{text: "对方不是店小二，付不了房租。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        # 扣钱：从 meta.coins 扣除 total
        meta = conn.character.meta
        money_map = Money.split(meta.coins || 0)

        case Money.pay(money_map, total) do
          {:ok, new_map} ->
            new_coins = Money.total_value(new_map)
            rent = Xiaoer.rent_per_night()

            new_meta =
              meta
              |> Map.put(:coins, new_coins)
              |> PlayerMeta.put_temp("rent_paid", total)

            character = Map.put(conn.character, :meta, new_meta)
            Records.save(character)

            change = total - rent

            text =
              if change > 0 do
                "你付给#{target_npc.name}#{Money.money_str(total)}房钱，找你#{Money.money_str(change)}文钱。\n" <>
                  "你已预付 #{total} 文房钱，可以上楼休息了。\n"
              else
                "你付给#{target_npc.name}#{Money.money_str(total)}房钱。\n" <>
                  "你已预付 #{total} 文房钱，可以上楼休息了。\n"
              end

            conn
            |> put_character(character)
            |> render(CommandView, "text", %{text: text})
            |> prompt(CommandView, "prompt", %{})

          :error ->
            conn
            |> render(CommandView, "text", %{text: "你身上的钱不够付#{Money.money_str(total)}。\n"})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  # 在当前房间按 id 或名称查找 NPC
  defp find_npc_in_room(conn, target) do
    room = Kantele.World.Room.snapshot(conn.character.room_id)
    private = room.private || %{}
    characters = Map.get(private, :characters, [])

    Enum.find(characters, fn char ->
      char.id == target or char.name == target
    end)
  end
end

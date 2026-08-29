defmodule Kantele.Npc.Vendor do
  @moduledoc """
  轻量商人（对应 `feature/vendor.c`）

  便携纯逻辑：按 `vendor_goods` 目录查询商品、失败价串/清单串。
  宿主负责持有 `vendor_goods`（`%{id/dir => item_map}`），item_map 形如
  `%{name, id, unit, value}`。

  价格串复用 `Kantele.Economy.Money` 的中文数字，若 `chinese/1` 不可用则回退
  十进制。
  """

  @doc """
  buy_object：按商品 key（`vendor_goods/{what}`）返回价值，未命中 0
  （对应 vendor.c buy_object/2）
  """
  def buy_object(vendor_goods, what) when is_map(vendor_goods) do
    case Map.get(vendor_goods, what) do
      nil -> 0
      %{value: v} when is_integer(v) -> v
      _ -> 0
    end
  end

  @doc """
  价格串（对应 vendor.c price_string/1，即 MONEY_D 显示样式）

  - 整除 10000 → "n两黄金"
  - 整除 100 → "n两白银"
  - 否则 "n文铜板"
  """
  def price_string(v) when is_integer(v) and v >= 0 do
    cond do
      rem(v, 10_000) == 0 -> chinese(div(v, 10_000)) <> "两黄金"
      rem(v, 100) == 0 -> chinese(div(v, 100)) <> "两白银"
      true -> chinese(v) <> "文铜板"
    end
  end

  @doc """
  商品清单（对应 vendor.c do_vendor_list/3 的字符串构造）

  goods: `%{key => item_map}`，item_map 至少含 `name/id/value/unit`。
  返回 `{inventory_res, list_string}`，inventory_res=是否本店主（arg 匹配 id）。
  """
  def vendor_list(goods, merchant_id, arg) do
    if not is_map(goods) do
      :error
    else
      rows =
        goods
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(fn {_key, item} ->
          val = Map.get(item, :value, 0)
          pad(item_name(item) <> "(" <> Map.get(item, :id, "") <> ")", 30) <>
            "：" <> price_string(val)
        end)

      list = "你可以购买下列这些东西：\n" <> Enum.join(rows, "\n") <> "\n"
      {is_merchant?(merchant_id, arg), list}
    end
  end

  defp is_merchant?(merchant_id, arg) do
    merchant_id != nil && merchant_id != "" && merchant_id == arg
  end

  defp item_name(%{name: n}) when is_binary(n), do: n
  defp item_name(_), do: ""

  defp pad(str, width) do
    pad_len = max(width - String.length(str), 0)
    str <> String.duplicate(" ", pad_len)
  end

  defp chinese(0), do: "零"
  defp chinese(n) when n in 1..9, do: Enum.at(~w(一 二 三 四 五 六 七 八 九), n - 1)
  defp chinese(n) when n in 10..19, do: "十" <> if(rem(n, 10) > 0, do: chinese(rem(n, 10)), else: "")
  defp chinese(n) when n in 20..99, do: chinese(div(n, 10)) <> "十" <> if(rem(n, 10) > 0, do: chinese(rem(n, 10)), else: "")
  defp chinese(n), do: Integer.to_string(n)
end
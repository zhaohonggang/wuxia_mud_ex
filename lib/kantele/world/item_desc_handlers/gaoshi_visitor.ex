defmodule Kantele.World.ItemDescHandlers.GaoshiVisitor do
  @moduledoc """
  数据驱动动态 `item_desc`：渲染扬州府通告访客计数条幅（P5-4q）。

  对应 LPC `d/city/guangchang.c` 的 `look_gaoshi()`：

      count = query("visitor");
      returnback = "\n"
        + "******************************************************************"
        + "********                    扬州府通告                    ********"
        + ...
        + "********    近期共有" + chinese_number(count) + "人通过此地。" + padding + "********";

  LPC 的 `query("visitor")` 是房间变量：玩家每次进入 `init()` 时
  `this_object()->add("visitor", 1)` 自增。本端口把计数落到房间
  `state.visitor`（UCL `state = { visitor = N }` 播种），由 room 进程内的
  `context.data.state` 读取，无需跨进程调用；运行期也可由
  `Room.put_state_by_id/3` 改写（对应 LPC 的 `add/set("visitor")`）。

  UCL 示例：

      item_desc = {
       gaoshi = { kind = "gaoshi_visitor" }
      }
      state = { visitor = 365 }

  条幅定宽（对齐到 65 显示列，与 LPC 逐字一致）；访客数经 `chinese_number/1`
  转中文数字，并按显示宽度补空格维持右框对齐（对应 LPC 的 `strwidth` 补位）。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView

  @default_text "这里没有这个东西。\n"

  # LPC guangchang.c 条幅定宽边框（逐字照搬，仅中间一行动态）。
  # 顶/底边框 65 个 *；侧栏 = 8 个 * + 49 个空格 + 8 个 * = 65 列。
  @border String.duplicate("*", 65)
  @side_inner String.duplicate(" ", 49)
  @title "扬州府通告"
  @lead "    近期共有"
  @tail "人通过此地。"

  def run(context, requester, _params) do
    text = render_text(context)
    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  defp render_text(context) do
    count = visitor_count(context)
    num = chinese_number(count)
    inner = @lead <> num <> @tail <> String.duplicate(" ", padding(num))
    line5 = "********" <> inner <> "********"
    side = "********" <> @side_inner <> "********"
    title_line = "********" <> title_inner() <> "********"

    ["" | [@border, side, title_line, side, line5, side, @border]]
    |> Enum.join("\n")
  end

  # “扬州府通告”为 5 个汉字；LPC 标题行 = 8* + 20空格 + 标题 + 20空格 + 8* = 61 列
  # （比 65 列的边框/侧栏窄 4 列，逐字照搬 LPC，不做“居中美化”）。
  defp title_inner do
    String.duplicate(" ", 20) <> @title <> String.duplicate(" ", 20)
  end

  # LPC 补位公式：26 - strwidth(chinese_number(count))，下限 0。
  defp padding(num), do: max(0, 26 - strwidth(num))

  defp visitor_count(context) do
    state = Map.get(context.data, :state, %{}) || %{}
    case Map.get(state, "visitor") do
      n when is_integer(n) and n > 0 -> n
      _ -> 0
    end
  end

  # ---- 中文数字（对应 LPC chinese_number，支持任意非负整数） ----
  @digits ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
  @units ["", "十", "百", "千"]

  defp chinese_number(n) when not is_integer(n), do: "零"
  defp chinese_number(0), do: "零"
  defp chinese_number(n) when n < 0, do: "负" <> chinese_number(-n)
  defp chinese_number(n) when n >= 100_000_000 do
    yi = div(n, 100_000_000)
    rest = rem(n, 100_000_000)
    chinese_number(yi) <> "亿" <> join_high(rest)
  end
  defp chinese_number(n) when n >= 10000 do
    wan = div(n, 10000)
    rest = rem(n, 10000)
    chinese_number(wan) <> "万" <> join_low(rest)
  end
  defp chinese_number(n), do: convert_below_10000(n)

  # 万级余数：为 0 则空；< 1000 补一个“零”桥接（如 十万零三）。
  defp join_low(0), do: ""
  defp join_low(rest) when rest < 1000, do: "零" <> convert_below_10000(rest)
  defp join_low(rest), do: convert_below_10000(rest)

  # 亿级余数（可能是 0..99999999）：拆成 万 段，缺段补零桥。
  defp join_high(0), do: ""
  defp join_high(rest) when rest < 1000, do: "零" <> chinese_number(rest)
  defp join_high(rest) do
    wan = div(rest, 10000)
    low = rem(rest, 10000)

    middle =
      if wan > 0 do
        chinese_number(wan) <> "万"
      else
        "零"
      end

    low_str =
      if low == 0 do
        ""
      else
        if low < 1000, do: "零" <> convert_below_10000(low), else: convert_below_10000(low)
      end

    middle <> low_str
  end

  # 0..9999 的中文数字（处理 0 桥接、十X 不写前导“一”）。
  defp convert_below_10000(0), do: ""
  defp convert_below_10000(n) when n > 0 and n < 10000 do
    digits = Integer.digits(n)
    total = length(digits)

    result =
      digits
      |> Enum.with_index()
      |> Enum.reduce({"", false}, fn {d, idx}, {acc, zero_pending} ->
        unit_pos = total - 1 - idx
        unit = Enum.at(@units, unit_pos)

        if d == 0 do
          {acc, true}
        else
          new_acc = if zero_pending, do: acc <> "零", else: acc
          {new_acc <> Enum.at(@digits, d) <> unit, false}
        end
      end)
      |> elem(0)

    # 10..19 不写前导“一”：一十X -> 十X
    case result do
      "一十" <> rest -> "十" <> rest
      other -> other
    end
  end
  defp convert_below_10000(_), do: ""

  # ---- 显示宽度（CJK 计 2 列，其余 1 列），对应 LPC strwidth ----
  defp strwidth(str) when is_binary(str) do
    String.graphemes(str)
    |> Enum.reduce(0, fn g, acc -> acc + if(wide?(g), do: 2, else: 1) end)
  end

  defp wide?(g) do
    [cp | _] = String.to_charlist(g)
    cp >= 0x2E80
  end

  defp ensure_newline(text) when is_binary(text), do: String.trim_trailing(text) <> "\n"
  defp ensure_newline(_text), do: @default_text
end

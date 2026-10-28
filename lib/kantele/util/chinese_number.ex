defmodule Kantele.Util.ChineseNumber do
  @moduledoc """
  中文数字（对应 `adm/daemons/chinesed.c` 的 `chinese_number/1`）

  LPC 的 `chinese_number()` 是 simul_efun，锻造报价等文案都用它把阿拉伯数字
  转成中文（`sprintf("...只需要%s两黄金", chinese_number(value))`）。

  本模块逐分支照抄原实现的判定顺序与拼接规则，包括它的几个「怪癖」：

  - `10` → `"十"`（不是 `"一十"`）；`11..19` → `"十X"`
  - `X百零Y`（`Y` 为 1..9 时补 `零`），如 `101` → `"一百零一"`
  - `X千零Y`（`Y < 100` 时补 `零`），如 `1010` → `"一千零十"`（LPC 原文如此）
  - `X万零Y`（`Y < 1000` 时补 `零`），如 `10500` → `"一万零五百"`
  - 负数加 `"负"` 前缀

  原实现 L61 有一处 `else if (i % 100 < 10)` 与 L58 完全重复（死分支，注释推测
  本意是 `< 20`）。照抄时**不复刻**该死分支 —— 它不可达，删掉不改变任何输出。

  > 超过 兆（10^12）的输入走最后一条分支，与原实现一致（不做溢出保护）。
  """

  @c_digit ~w(零 十 百 千 万 亿 兆)
  @c_num ~w(零 一 二 三 四 五 六 七 八 九 十)

  @doc """
  整数转中文数字字符串。

      iex> Kantele.Util.ChineseNumber.to_chinese(220)
      "二百二十"
      iex> Kantele.Util.ChineseNumber.to_chinese(500)
      "五百"
      iex> Kantele.Util.ChineseNumber.to_chinese(2_200_000)
      "二百二十万"
  """
  def to_chinese(i) when is_integer(i) and i < 0, do: "负" <> to_chinese(-i)
  def to_chinese(i) when is_integer(i) and i < 11, do: num(i)

  def to_chinese(i) when i < 20, do: digit(1) <> num(i - 10)

  def to_chinese(i) when i < 100 do
    if rem(i, 10) != 0 do
      num(div(i, 10)) <> digit(1) <> num(rem(i, 10))
    else
      num(div(i, 10)) <> digit(1)
    end
  end

  def to_chinese(i) when i < 1_000 do
    cond do
      rem(i, 100) == 0 ->
        num(div(i, 100)) <> digit(2)

      rem(i, 100) < 10 ->
        num(div(i, 100)) <> digit(2) <> num(0) <> to_chinese(rem(i, 100))

      true ->
        num(div(i, 100)) <> digit(2) <> to_chinese(rem(i, 100))
    end
  end

  def to_chinese(i) when i < 10_000 do
    cond do
      rem(i, 1_000) == 0 ->
        num(div(i, 1_000)) <> digit(3)

      rem(i, 1_000) < 100 ->
        num(div(i, 1_000)) <> digit(3) <> num(0) <> to_chinese(rem(i, 1_000))

      true ->
        num(div(i, 1_000)) <> digit(3) <> to_chinese(rem(i, 1_000))
    end
  end

  def to_chinese(i) when i < 100_000_000 do
    cond do
      rem(i, 10_000) == 0 ->
        to_chinese(div(i, 10_000)) <> digit(4)

      rem(i, 10_000) < 1_000 ->
        to_chinese(div(i, 10_000)) <> digit(4) <> num(0) <> to_chinese(rem(i, 10_000))

      true ->
        to_chinese(div(i, 10_000)) <> digit(4) <> to_chinese(rem(i, 10_000))
    end
  end

  def to_chinese(i) when i < 1_000_000_000_000 do
    cond do
      rem(i, 100_000_000) == 0 ->
        to_chinese(div(i, 100_000_000)) <> digit(5)

      rem(i, 100_000_000) < 1_000_000 ->
        to_chinese(div(i, 100_000_000)) <> digit(5) <> num(0) <> to_chinese(rem(i, 100_000_000))

      true ->
        to_chinese(div(i, 100_000_000)) <> digit(5) <> to_chinese(rem(i, 100_000_000))
    end
  end

  def to_chinese(i) do
    cond do
      rem(i, 1_000_000_000_000) == 0 ->
        to_chinese(div(i, 1_000_000_000_000)) <> digit(6)

      rem(i, 1_000_000_000_000) < 100_000_000 ->
        to_chinese(div(i, 1_000_000_000_000)) <>
          digit(6) <> num(0) <> to_chinese(rem(i, 1_000_000_000_000))

      true ->
        to_chinese(div(i, 1_000_000_000_000)) <>
          digit(6) <> to_chinese(rem(i, 1_000_000_000_000))
    end
  end

  defp num(i), do: Enum.at(@c_num, i)
  defp digit(i), do: Enum.at(@c_digit, i)
end

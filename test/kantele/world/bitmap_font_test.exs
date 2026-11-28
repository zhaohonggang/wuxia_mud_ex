defmodule Kantele.World.BitmapFontTest do
  @moduledoc """
  A-5-c C3：点阵字库原语。

  期望值由 `scripts/build_hzk16_utf8_pack.py` 用 LPC bitmap_font.c 原算法
  （Python 复刻，同一份 HZK16? 字库数据）生成：`test/fixtures/bitmap_font/`。
  ex 侧按 UTF-8 码点直查 pack（用户 2026-11-28 指定，运行时无 GBK 换算），
  位掩码展开与 LPC 逐条一致，故两者输出必须逐行相同。
  """

  use ExUnit.Case, async: false

  alias Kantele.World.BitmapFont

  @fixture_dir "test/fixtures/bitmap_font"
  @read_error "Can't read bytes from character lib.\n"

  defp fixture(name) do
    @fixture_dir
    |> Path.join(name)
    |> File.read!()
  end

  test "汉词「国富」变体 C：与 LPC 原算法输出逐行一致" do
    assert BitmapFont.render("国富", 16, font: "C") == fixture("国富_C.txt")
  end

  test "汉词「国富」变体 F：与 LPC 原算法输出逐行一致" do
    assert BitmapFont.render("国富", 16, font: "F") == fixture("国富_F.txt")
  end

  test "汉词「民强」变体 K、「龙腾」变体 Y：与 LPC 原算法输出逐行一致" do
    assert BitmapFont.render("民强", 16, font: "K") == fixture("民强_K.txt")
    assert BitmapFont.render("龙腾", 16, font: "Y") == fixture("龙腾_Y.txt")
  end

  test "纯 ASCII 与混排「A国」：ASC16 字节索引 + 汉字码点索引" do
    assert BitmapFont.render("AB", 16, font: "C") == fixture("AB_C.txt")
    assert BitmapFont.render("A国", 16, font: "S") == fixture("A国_S.txt")
  end

  test "缺省随机变体：仍是 16 行点阵，行宽 = 16 × 字数，仅含 8/-" do
    text = BitmapFont.render("国富", 16)
    lines = String.split(text, "\n")

    assert length(lines) == 16
    # 每个汉字占 16 列，二字词并排 → 行宽 32
    assert Enum.all?(lines, fn line -> String.length(line) == 32 end)
    assert Enum.all?(lines, fn line -> String.match?(line, ~r/^[8-]+$/) end)
  end

  test "字体变体池对齐 LPC element_of 九选一" do
    assert BitmapFont.font_variants() == ["C", "F", "H", "K", "L", "S", "V", "X", "Y"]
  end

  test "字库中不存在的字形 → LPC 同款错误串" do
    # 私用区码点不在任何字库内
    assert BitmapFont.render("\uE000", 16, font: "C") == @read_error
  end
end

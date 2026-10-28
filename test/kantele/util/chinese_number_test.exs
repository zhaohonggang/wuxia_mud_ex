defmodule Kantele.Util.ChineseNumberTest do
  use ExUnit.Case, async: true

  alias Kantele.Util.ChineseNumber

  describe "个位与十几" do
    test "0..10 逐个对应 c_num 表" do
      assert ChineseNumber.to_chinese(0) == "零"
      assert ChineseNumber.to_chinese(1) == "一"
      assert ChineseNumber.to_chinese(2) == "二"
      assert ChineseNumber.to_chinese(9) == "九"
      # LPC：i < 11 直接取 c_num[i]，而 c_num[10] 就是「十」
      assert ChineseNumber.to_chinese(10) == "十"
    end

    test "11..19 是「十X」而不是「一十X」" do
      assert ChineseNumber.to_chinese(11) == "十一"
      assert ChineseNumber.to_chinese(15) == "十五"
      assert ChineseNumber.to_chinese(19) == "十九"
    end
  end

  describe "两位数" do
    test "整十与带尾数" do
      assert ChineseNumber.to_chinese(20) == "二十"
      assert ChineseNumber.to_chinese(21) == "二十一"
      assert ChineseNumber.to_chinese(99) == "九十九"
    end
  end

  describe "三位数" do
    test "整百 / 补零 / 不补零" do
      assert ChineseNumber.to_chinese(100) == "一百"
      assert ChineseNumber.to_chinese(101) == "一百零一"
      # LPC：i%100 = 10 不补零，直接递归 chinese_number(10) = 「十」
      # 所以 110 读「一百十」、111 读「一百十一」（不是「一百一十」）
      assert ChineseNumber.to_chinese(110) == "一百十"
      assert ChineseNumber.to_chinese(111) == "一百十一"
      assert ChineseNumber.to_chinese(220) == "二百二十"
      assert ChineseNumber.to_chinese(500) == "五百"
      assert ChineseNumber.to_chinese(999) == "九百九十九"
    end
  end

  describe "四位数" do
    test "整千 / 补零 / 不补零" do
      assert ChineseNumber.to_chinese(1_000) == "一千"
      assert ChineseNumber.to_chinese(1_001) == "一千零一"
      # LPC 原文：i%1000 < 100 就补「零」，所以 1010 是「一千零十」
      assert ChineseNumber.to_chinese(1_010) == "一千零十"
      assert ChineseNumber.to_chinese(1_100) == "一千一百"
      assert ChineseNumber.to_chinese(1_234) == "一千二百三十四"
      assert ChineseNumber.to_chinese(9_999) == "九千九百九十九"
    end
  end

  describe "万 / 亿 / 兆" do
    test "万位" do
      assert ChineseNumber.to_chinese(10_000) == "一万"
      assert ChineseNumber.to_chinese(10_500) == "一万零五百"
      assert ChineseNumber.to_chinese(11_000) == "一万一千"
      assert ChineseNumber.to_chinese(12_000) == "一万二千"
      assert ChineseNumber.to_chinese(100_000) == "十万"
    end

    test "亿位" do
      assert ChineseNumber.to_chinese(100_000_000) == "一亿"
      assert ChineseNumber.to_chinese(1_000_000_000) == "十亿"
    end

    test "兆位" do
      assert ChineseNumber.to_chinese(1_000_000_000_000) == "一兆"
    end
  end

  describe "负数" do
    test "加「负」前缀" do
      assert ChineseNumber.to_chinese(-220) == "负二百二十"
      assert ChineseNumber.to_chinese(-1) == "负一"
    end
  end

  describe "锻造报价实际用到的值" do
    test "材料估价 power_point*2+20 与乾坤袋 value/60" do
      # 玄铁 power_point=100 → 220 两黄金
      assert ChineseNumber.to_chinese(220) == "二百二十"
      # 乾坤石 value=30000 → 500 两黄金
      assert ChineseNumber.to_chinese(div(30_000, 60)) == "五百"
    end
  end
end

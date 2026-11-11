defmodule Kantele.World.SnowRegionTest do
  use ExUnit.Case, async: true

  alias Kantele.World.SnowRegion

  describe "winter?/1 —— 冬月判定（12,1,2,3,4,5）" do
    test "12/1/2/3/4/5 为真" do
      assert SnowRegion.winter?(12)
      assert SnowRegion.winter?(1)
      assert SnowRegion.winter?(2)
      assert SnowRegion.winter?(3)
      assert SnowRegion.winter?(4)
      assert SnowRegion.winter?(5)
    end

    test "其余月份为假" do
      refute SnowRegion.winter?(6)
      refute SnowRegion.winter?(7)
      refute SnowRegion.winter?(8)
      refute SnowRegion.winter?(9)
      refute SnowRegion.winter?(10)
      refute SnowRegion.winter?(11)
    end
  end

  describe "guanwai?/1 —— 房间以 guanwai: 开头" do
    test "guanwai: 前缀为真" do
      assert SnowRegion.guanwai?("guanwai:xueyuan")
      assert SnowRegion.guanwai?("guanwai:hujiacun")
    end

    test "其余房间为假" do
      refute SnowRegion.guanwai?("city:wumiao")
      refute SnowRegion.guanwai?("beijing:kangfu_men")
      refute SnowRegion.guanwai?(nil)
    end
  end

  describe "cold_damage/5 —— 寒冷伤害公式（逐字对齐 LPC do_cold）" do
    test "基础：35 - con_resist，不为负" do
      # con=20 -> con/2=10 + random(20)=0 => 10；35-10=25
      # hour=12 (11..13) -> ×0.5 => 25-12=13；scale=1 => 13
      {damage, _msg} = SnowRegion.cold_damage(10, 0, 12, 1, false)
      assert 13 = damage
    end

    test "damage < 0 -> 0" do
      # con=80 -> 40+0=40；35-40=-5 -> max 0
      {damage, _msg} = SnowRegion.cold_damage(40, 0, 12, 1, false)
      assert 0 = damage
    end

    test "关外胡家：damage -= 25" do
      # con=20 -> 10；35-10=25；hour=12 -> ×0.5 => 13；born_hu -> 13-25=-12 -> 0
      {damage, _msg} = SnowRegion.cold_damage(10, 0, 12, 1, true)
      assert 0 = damage
    end

    test "夜间（<=6 或 >=18）：×1.5" do
      # con=20 -> 10；35-10=25；hour=18 -> ×1.5 => 25+12=37
      {damage, _msg} = SnowRegion.cold_damage(10, 0, 18, 1, false)
      assert 37 = damage
    end

    test "深夜（<=4 或 >=22）：再 ×1.5（累计）" do
      # con=20 -> 10；35-10=25；hour=2 -> 25+12=37（<=6）；再<=4 => 37+18=55
      {damage, _msg} = SnowRegion.cold_damage(10, 0, 2, 1, false)
      assert 55 = damage
    end

    test "正午（11-13）：×0.5" do
      {damage, _msg} = SnowRegion.cold_damage(10, 0, 11, 1, false)
      assert 13 = damage  # 25-12=13
    end

    test "scale=3（出关）：damage × 3" do
      # con=20 -> 10；35-10=25；hour=12 -> 13；scale=3 => 39
      {damage, _msg} = SnowRegion.cold_damage(10, 0, 12, 3, false)
      assert 39 = damage
    end

    test "warm 抵消伤害" do
      # con=20 -> 10；warm=10；35-(10+10)=15；hour=12 -> ×0.5 => 15-7=8
      {damage, _msg} = SnowRegion.cold_damage(10, 10, 12, 1, false)
      assert 8 = damage
    end
  end

  describe "cold_msg/1 —— 伤害文案阈值" do
    test ">80" do
      assert SnowRegion.cold_msg(90) =~ "血液都快被冻住了"
    end

    test ">60" do
      assert SnowRegion.cold_msg(70) =~ "非常僵硬"
    end

    test ">40" do
      assert SnowRegion.cold_msg(50) =~ "冷气透过衣衫"
    end

    test ">20" do
      assert SnowRegion.cold_msg(30) =~ "人都要麻木了"
    end

    test ">10" do
      assert SnowRegion.cold_msg(15) =~ "天气非常的冷"
    end

    test ">0" do
      assert SnowRegion.cold_msg(5) =~ "有点冷"
    end

    test "<=0" do
      assert SnowRegion.cold_msg(0) =~ "挺暖和的"
    end
  end

  describe "dongshang_duration/2 —— 冻伤持续时间" do
    test "damage > 10：existing + 5 + damage/3" do
      assert 15 = SnowRegion.dongshang_duration(30, 0)   # 0 + 5 + 10
      assert 20 = SnowRegion.dongshang_duration(30, 5)   # 5 + 5 + 10
      assert 12 = SnowRegion.dongshang_duration(21, 0)   # 0 + 5 + 7
    end

    test "damage <= 10：0（不落冻伤）" do
      assert 0 = SnowRegion.dongshang_duration(10, 100)
      assert 0 = SnowRegion.dongshang_duration(5, 0)
    end
  end

  describe "cold_event_for/3 —— 非关外始终返回 nil（与月份无关，确定性）" do
    test "非关外房间返回 nil" do
      char = %{meta: %{stats: %{con: 20}}}
      assert is_nil(SnowRegion.cold_event_for(char, "city:wumiao", 3))
      assert is_nil(SnowRegion.cold_event_for(char, "beijing:kangfu_men", 3))
      assert is_nil(SnowRegion.cold_event_for(char, nil, 3))
    end
  end
end

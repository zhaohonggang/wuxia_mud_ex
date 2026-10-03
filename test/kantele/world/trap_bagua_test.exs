defmodule Kantele.World.Trap.BaguaTest do
  @moduledoc """
  少林八卦阵（`d/shaolin/bagua.h` 的 `check_dirs/2`）纯逻辑

  两处最容易做错、也最该被钉住的地方：

    1. **汉字对应**。艮 U+826E、巽 U+5DFD 曾经弄反过（控制台吞字），
       而两者行为完全不同：艮扣 combat_exp、巽受 qi 伤。
       所以这里直接断言码点，不靠肉眼。
    2. **惩罚只在走对时发生**。LPC 里 `receive_damage` 等写在
       `if (bc 匹配)` 的 then 分支里 —— 走错只是清零，不受罚。
  """
  use ExUnit.Case, async: true

  alias Kantele.World.Trap.Bagua

  describe "拼音 -> 汉字映射（LPC switch 与 temp 键都用汉字）" do
    test "八个方向的汉字与码点都对" do
      assert Bagua.han("kan") == "坎"
      assert Bagua.han("kun") == "坤"
      assert Bagua.han("li") == "离"
      assert Bagua.han("qian") == "乾"
      assert Bagua.han("gen") == "艮"
      assert Bagua.han("zhen") == "震"
      assert Bagua.han("xun") == "巽"
      assert Bagua.han("dui") == "兑"
    end

    test "艮是 U+826E、巽是 U+5DFD（别弄反）" do
      # 艮扣 combat_exp
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 3}, "gen")
      assert {:add, :combat_exp, -50} in effects

      # 巽是 receive_wound(qi)
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 6}, "xun")
      assert {:wound, :qi, 50} in effects

      # 走错时不该出现这些惩罚
      assert {:allow, wrong} = Bagua.evaluate(%{"bagua/count" => 2}, "gen")
      assert {:delete_temp, "bagua/count"} in wrong
      refute Enum.any?(wrong, &match?({:add, :combat_exp, _}, &1))
      refute Enum.any?(wrong, &match?({:wound, _, _}, &1))
    end

    test "temp 键用的是汉字" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 0}, "kan")
      assert {:set_temp, "bagua/坎", 1} in effects
    end
  end

  describe "count 匹配表（每个方向允许的 count）" do
    # LPC switch：bc == 0||13||17 / 总是清零 / 1||12 / 8 / 3||4||15 /
    #             2||7||9 / 6||11 / 5||10||14||16
    @table [
      {"kan", [0, 13, 17]},
      {"li", [1, 12]},
      {"qian", [8]},
      {"gen", [3, 4, 15]},
      {"zhen", [2, 7, 9]},
      {"xun", [6, 11]},
      {"dui", [5, 10, 14, 16]}
    ]

    # 注意：不能写成 `for {dir, allowed} <- @table do test ... end` ——
    # test 是宏，宏体里的捕获变量不会被带进生成的函数，会变成
    # undefined function allowed/0。这里在一个 test 内遍历。
    test "每个方向只在 LPC 允许的 count 上算踩对" do
      for {dir, allowed} <- @table do
        for count <- 0..18 do
          expected = count in allowed

          assert Bagua.correct?(dir, count) == expected,
                 "#{dir} 在 count=#{count} 应为 #{expected}（LPC 允许 #{inspect(allowed)}）"
        end
      end
    end

    test "坤（kun）永远不算踩对" do
      for count <- 0..18 do
        refute Bagua.correct?("kun", count)
      end
    end
  end

  describe "走对：count + 1 并吃该方向的惩罚" do
    test "count=0 往 kan -> count=1 且受 jing 伤" do
      assert {:allow, effects} = Bagua.evaluate(%{}, "kan")

      assert effects == [
               {:set_temp, "bagua/count", 1},
               {:damage, :jing, 50},
               {:set_temp, "bagua/坎", 1}
             ]
    end

    test "count=1 往 li -> count=2 且掉内力" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 1}, "li")

      assert {:set_temp, "bagua/count", 2} in effects
      assert {:add, :neili, -50} in effects
    end

    test "count=2 往 zhen -> 昏厥" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 2}, "zhen")
      assert {:faint} in effects
    end

    test "count=8 往 qian -> 受 qi 伤" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 8}, "qian")
      assert {:damage, :qi, 50} in effects
    end
  end

  describe "走错：只清零，不受罚" do
    test "count=5 往 kan（只允许 0/13/17）-> 只删 count" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 5}, "kan")

      assert {:delete_temp, "bagua/count"} in effects

      # 关键：不该有任何惩罚
      refute Enum.any?(effects, &match?({:damage, _, _}, &1))
      refute Enum.any?(effects, &match?({:wound, _, _}, &1))
      refute Enum.any?(effects, &match?({:add, _, _}, &1))
      refute Enum.any?(effects, &match?({:faint}, &1))
    end

    test "走错时方向计数照样累加（脱困靠的就是它）" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 5}, "kan")
      assert {:set_temp, "bagua/坎", 1} in effects
    end
  end

  describe "坤（kun）：清空整个 bagua，不累加方向计数" do
    test "delete count + 清空子树，没有方向计数" do
      assert {:allow, effects} = Bagua.evaluate(%{"bagua/count" => 3}, "kun")

      assert effects == [
               {:delete_temp, "bagua/count"},
               {:delete_prefix, "bagua/"}
             ]
    end
  end

  describe "脱困：同一方向连走 14 次" do
    test "第 13 次还不脱困，第 14 次脱困并进僧监" do
      # 先把某方向计数推到 13
      temp = %{"bagua/坎" => 12}

      # 第 13 次（count 13 -> 14，不>13）
      assert {:allow, effects} = Bagua.evaluate(temp, "kan")
      assert {:set_temp, "bagua/坎", 13} in effects
      refute Enum.any?(effects, &match?({:force_move, _}, &1))

      # 第 14 次（13 -> 14 > 13）
      temp2 = %{"bagua/坎" => 13}

      assert {:block, msg, effects} = Bagua.evaluate(temp2, "kan")
      assert msg == "你踩动了机关，掉进僧监。"
      assert {:force_move, "shaolin:jianyu"} in effects
      assert {:delete_prefix, "bagua/"} in effects
    end

    test "脱困那一步仍然先吃伤害（LPC 里惩罚写在 count+1 的同一分支）" do
      assert {:block, _msg, effects} = Bagua.evaluate(%{"bagua/坎" => 13}, "kan")
      assert {:damage, :jing, 50} in effects
    end
  end

  describe "非八卦方向" do
    test "down / up 等原样放行、无副作用" do
      for dir <- ["down", "up", "northeast", "out"] do
        assert {:allow, []} = Bagua.evaluate(%{"bagua/count" => 3}, dir),
               "#{dir} 不该触发"
      end
    end
  end

  describe("按正确顺序走一遍（count 0 -> 18）") do
    test "从 count=0 出发的正确路径" do
      # 由匹配表推导：count -> 下一个该走的方向
      path = [
        {0, "kan"}, {1, "li"}, {2, "zhen"}, {3, "gen"}, {4, "gen"},
        {5, "dui"}, {6, "xun"}, {7, "zhen"}, {8, "qian"}, {9, "zhen"},
        {10, "dui"}, {11, "xun"}, {12, "li"}, {13, "kan"}, {14, "dui"},
        {15, "gen"}, {16, "dui"}, {17, "kan"}
      ]

      # 每一步都应该是「踩对」
      for {count, dir} <- path do
        assert Bagua.correct?(dir, count),
               "count=#{count} 时应走 #{dir}（han=#{Bagua.han(dir)}）"
      end
    end
  end
end
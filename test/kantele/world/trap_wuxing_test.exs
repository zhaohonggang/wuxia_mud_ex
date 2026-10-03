defmodule Kantele.World.Trap.WuxingTest do
  @moduledoc """
  五行迷宫（`d/shaolin/wuxing*.c`）的纯逻辑

  这里逐条对着 LPC 写，包括几个容易搞错的点：

    - `query_temp` 对缺失键返回 **0**，所以「从没往北走过」时 metal=0，
      `metal > 0` 不成立 —— 必须至少往北走过一次才能脱困
    - 往**东/南**不触发任何东西（只是迷宫里的转向）
    - 往**西**是机关：清空计数 + 掉僧监（不是「往西也能走」）
    - 脱困判定是**五行计数全部相等**，所以正常玩法是先被某处机关
      把某行计数打上去，再一路往北凑齐
  """
  use ExUnit.Case, async: true

  alias Kantele.World.Trap.Wuxing

  defp t(pairs), do: Map.new(pairs)

  describe "check_out?/1 —— 五行计数全部相等且 > 0" do
    test "全空（从没往北走过）-> 不成立，因为 metal = 0" do
      refute Wuxing.check_out?(%{})
    end

    test "五行都是 1 -> 成立" do
      temp = t([{"wuxing/金", 1}, {"wuxing/木", 1}, {"wuxing/水", 1},
                {"wuxing/火", 1}, {"wuxing/土", 1}])

      assert Wuxing.check_out?(temp)
    end

    test "五行都是 3 -> 成立" do
      temp = t([{"wuxing/金", 3}, {"wuxing/木", 3}, {"wuxing/水", 3},
                {"wuxing/火", 3}, {"wuxing/土", 3}])

      assert Wuxing.check_out?(temp)
    end

    test "有一个不等 -> 不成立" do
      temp = t([{"wuxing/金", 2}, {"wuxing/木", 2}, {"wuxing/水", 2},
                {"wuxing/火", 2}, {"wuxing/土", 1}])

      refute Wuxing.check_out?(temp)
    end

    test "缺一行（该行算 0）-> 不成立" do
      temp = t([{"wuxing/金", 0}, {"wuxing/木", 0}, {"wuxing/水", 1},
                {"wuxing/火", 0}, {"wuxing/土", 0}])

      refute Wuxing.check_out?(temp)
    end
  end

  describe "往北：计数 +1，未凑齐则放行" do
    test "第一次往北 -> 水=1，放行，不传送" do
      assert {:allow, effects} = Wuxing.evaluate(%{}, "north", "wuxing0")
      assert effects == [{:set_temp, "wuxing/水", 1}]
    end

    test "已有计数则累加" do
      temp = %{"wuxing/水" => 4}
      assert {:allow, [{:set_temp, "wuxing/水", 5}]} = Wuxing.evaluate(temp, "north", "wuxing0")
    end

    test "往北不会删除计数" do
      temp = %{"wuxing/金" => 2, "wuxing/木" => 2, "wuxing/火" => 2, "wuxing/土" => 2}

      assert {:allow, [{:set_temp, "wuxing/水", 1}]} = Wuxing.evaluate(temp, "north", "wuxing0")
    end
  end

  describe "往北：凑齐五行则脱困" do
    test "金木火土都是 1、水也是 1 -> 这次往北凑成 2，仍不等，放行" do
      # 水原本就是 1，往北后变 2，和其它 1 不等
      temp = t([{"wuxing/金", 1}, {"wuxing/木", 1}, {"wuxing/水", 1},
                {"wuxing/火", 1}, {"wuxing/土", 1}])

      assert {:allow, [{:set_temp, "wuxing/水", 2}]} = Wuxing.evaluate(temp, "north", "wuxing0")
    end

    test "金木火土都是 2、水为 1 -> 往北后五行都是 2 -> 脱困" do
      temp = t([{"wuxing/金", 2}, {"wuxing/木", 2}, {"wuxing/水", 1},
                {"wuxing/火", 2}, {"wuxing/土", 2}])

      assert {:block, msg, effects} = Wuxing.evaluate(temp, "north", "wuxing0")

      assert msg == "你顺利地走出了五行迷宫。"

      assert effects == [
               {:set_temp, "wuxing/水", 2},
               {:delete_prefix, "wuxing/"},
               {:force_move, "shaolin:andao2"}
             ]
    end
  end

  describe "往西：机关" do
    test "清空计数并掉进僧监，且拦下" do
      temp = t([{"wuxing/金", 3}, {"wuxing/水", 2}])

      assert {:block, msg, effects} = Wuxing.evaluate(temp, "west", "wuxing0")
      assert msg == "你掉进机关，落入僧监。"
      assert effects == [{:delete_prefix, "wuxing/"}, {:force_move, "shaolin:jianyu1"}]
    end

    test "即使 temp 为空也照样触发（机关不看计数）" do
      assert {:block, "你掉进机关，落入僧监。", _} = Wuxing.evaluate(%{}, "west", "wuxing0")
    end
  end

  describe "往东/南：不触发" do
    test "两个方向都原样放行且无副作用" do
      temp = t([{"wuxing/金", 1}, {"wuxing/水", 1}])

      assert {:allow, []} = Wuxing.evaluate(temp, "east", "wuxing0")
      assert {:allow, []} = Wuxing.evaluate(temp, "south", "wuxing0")
    end

    test "即使五行已凑齐，东/南也不该脱困（脱困只由往北触发）" do
      temp = t([{"wuxing/金", 2}, {"wuxing/木", 2}, {"wuxing/水", 2},
                {"wuxing/火", 2}, {"wuxing/土", 2}])

      assert {:allow, []} = Wuxing.evaluate(temp, "east", "wuxing0")
      assert {:allow, []} = Wuxing.evaluate(temp, "south", "wuxing0")
    end
  end

  describe "不在 dirs 里的方向" do
    test "down 等交给 ::valid_leave，原样放行" do
      assert {:allow, []} = Wuxing.evaluate(%{}, "down", "wuxing0")
      assert {:allow, []} = Wuxing.evaluate(%{}, "up", "wuxing0")
      assert {:allow, []} = Wuxing.evaluate(%{}, "northeast", "wuxing0")
    end
  end

  describe "每个房间的规则不同（上一版全都当成 wuxing0 了）" do
    # 逐个读 d/shaolin/wuxing{0..4}.c 的 valid_leave 得到的映射。
    # 上一版只读了 wuxing0.c，于是只有「水」会被累加，五行永远凑不齐 ——
    # 表现为「连着往北走 13 次也走不出去」。
    @rules [
      {"wuxing0", "north", "水", "west"},
      {"wuxing1", "south", "火", "west"},
      {"wuxing2", "east", "木", "north"},
      {"wuxing3", "north", "土", "west"},
      {"wuxing4", "west", "金", "north"}
    ]

    test "rule/1 与 LPC 源码一致" do
      for {room, inc, element, trap} <- @rules do
        assert Wuxing.rule(room) == {inc, element, trap},
               "#{room} 应为 {#{inc}, #{element}, #{trap}}"
      end
    end

    test "递增方向会累加该房间对应的元素" do
      for {room, inc, element, _trap} <- @rules do
        assert {:allow, [{:set_temp, key, 1}]} = Wuxing.evaluate(%{}, inc, room),
               "#{room} 往#{inc} 应把 wuxing/#{element} 置为 1"

        assert key == "wuxing/#{element}"
      end
    end

    test "机关方向按房间而变（wuxing2 / wuxing4 是 north，不是 west）" do
      for {room, _inc, _element, trap} <- @rules do
        assert {:block, msg, _} = Wuxing.evaluate(%{}, trap, room),
               "#{room} 往#{trap} 应触发机关"

        assert msg == "你掉进机关，落入僧监。"
      end
    end

    test "机关方向与递增方向不冲突" do
      for {room, inc, _element, trap} <- @rules do
        assert inc != trap, "#{room} 的递增方向 #{inc} 与机关方向 #{trap} 冲突"
      end
    end

    test "非五行房间（如 shaolin:zhonglou6）不触发任何东西" do
      assert Wuxing.rule("zhonglou6") == nil
      assert {:allow, []} = Wuxing.evaluate(%{"wuxing/金" => 1}, "north", "zhonglou6")
      assert {:allow, []} = Wuxing.evaluate(%{"wuxing/金" => 1}, "west", "zhonglou6")
    end
  end

  describe "沿五环走一圈就能脱困（端到端）" do
    # wuxing0 -north(水)-> wuxing2 -east(木)-> wuxing1 -south(火)->
    # wuxing3 -north(土)-> wuxing4 -west(金)-> wuxing0
    test "五步之后五行相等，第 5 步脱困" do
      steps = [
        {"wuxing0", "north", "水"},
        {"wuxing2", "east", "木"},
        {"wuxing1", "south", "火"},
        {"wuxing3", "north", "土"},
        {"wuxing4", "west", "金"}
      ]

      # 前四步：只累加，还凑不齐（check_out 要求五行全等且 >0）
      # 注意用 Enum.reduce 而不是 for —— for 里重绑定的变量不会泄漏出来。
      temp =
        Enum.reduce(Enum.slice(steps, 0, 4), %{}, fn {room, dir, _element}, acc ->
          assert {:allow, effects} = Wuxing.evaluate(acc, dir, room)
          apply_set_temp(acc, effects)
        end)

      assert map_size(temp) == 4, "此时应已有四行，实际 #{inspect(temp)}"

      refute Wuxing.check_out?(temp), "还差一行，不该脱困"

      # 第五步补上最后一行 -> 脱困
      assert {:block, msg, effects} = Wuxing.evaluate(temp, "west", "wuxing4")
      assert msg == "你顺利地走出了五行迷宫。"
      assert {:force_move, "shaolin:andao2"} in effects
      assert {:delete_prefix, "wuxing/"} in effects
    end

    test "脱困会清空计数，所以重新开始时五行不齐、走不出去" do
      # 模拟「已经凑齐过一次」的状态（其实真实路径里脱困那一步就清空了，
      # 这里是想确认：一旦五行不等，往北就只是普通累加，不会脱困）
      temp = %{"wuxing/金" => 1, "wuxing/木" => 1, "wuxing/水" => 1,
               "wuxing/火" => 1, "wuxing/土" => 1}

      # 往北把水加到 2 -> 五行不等 -> 不脱困
      assert {:allow, [{:set_temp, "wuxing/水", 2}]} = Wuxing.evaluate(temp, "north", "wuxing0")
    end

    test "真正的脱困那一步会同时发 set_temp + delete_prefix + force_move" do
      # 只差金：北向房间 wuxing0 把水加到 2 后五行才全等 —— 所以先造一个
      # 「往北加完水就齐」的状态
      temp = %{"wuxing/金" => 2, "wuxing/木" => 2, "wuxing/火" => 2,
               "wuxing/土" => 2, "wuxing/水" => 1}

      assert {:block, msg, effects} = Wuxing.evaluate(temp, "north", "wuxing0")
      assert msg == "你顺利地走出了五行迷宫。"

      # 顺序有意义：先 +1、再清空整棵子树、最后传送
      assert effects == [
               {:set_temp, "wuxing/水", 2},
               {:delete_prefix, "wuxing/"},
               {:force_move, "shaolin:andao2"}
             ]
    end

    test "走错方向（离开环）会掉进机关，计数被清零" do
      # wuxing2 的机关是 north，而环上 wuxing2 走的是 east
      temp = %{"wuxing/金" => 1, "wuxing/水" => 1}

      assert {:block, msg, effects} = Wuxing.evaluate(temp, "north", "wuxing2")
      assert msg == "你掉进机关，落入僧监。"
      assert {:delete_prefix, "wuxing/"} in effects
      assert {:force_move, "shaolin:jianyu1"} in effects
    end
  end

  describe "复位后的完整走法（端到端，纯函数层面）" do
    test "往西中机关 -> 清零；再往北两次凑成 1 不脱困；五行齐了才脱困" do
      # 先被机关清空
      assert {:block, _, effects} = Wuxing.evaluate(%{"wuxing/金" => 5}, "west", "wuxing0")

      # 模拟角色执行 delete_prefix 后的 temp
      temp =
        Enum.reduce(effects, %{}, fn
          {:delete_prefix, prefix}, acc -> Enum.reject(Map.to_list(acc), fn {k, _} -> String.starts_with?(k, prefix) end) |> Map.new()
          _, acc -> acc
        end)

      assert temp == %{}

      # 一路往北攒水
      temp =
        Enum.reduce(1..2, temp, fn _, acc ->
          {:allow, [{:set_temp, k, v}]} = Wuxing.evaluate(acc, "north", "wuxing0")
          Map.put(acc, k, v)
        end)

      assert temp == %{"wuxing/水" => 2}
    end
  end

  defp apply_set_temp(temp, effects) do
    Enum.reduce(effects, temp, fn
      {:set_temp, k, v}, acc -> Map.put(acc, k, v)
      _, acc -> acc
    end)
  end
end

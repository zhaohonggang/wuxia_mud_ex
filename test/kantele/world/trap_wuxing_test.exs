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
      assert {:allow, effects} = Wuxing.evaluate(%{}, "north")
      assert effects == [{:set_temp, "wuxing/水", 1}]
    end

    test "已有计数则累加" do
      temp = %{"wuxing/水" => 4}
      assert {:allow, [{:set_temp, "wuxing/水", 5}]} = Wuxing.evaluate(temp, "north")
    end

    test "往北不会删除计数" do
      temp = %{"wuxing/金" => 2, "wuxing/木" => 2, "wuxing/火" => 2, "wuxing/土" => 2}

      assert {:allow, [{:set_temp, "wuxing/水", 1}]} = Wuxing.evaluate(temp, "north")
    end
  end

  describe "往北：凑齐五行则脱困" do
    test "金木火土都是 1、水也是 1 -> 这次往北凑成 2，仍不等，放行" do
      # 水原本就是 1，往北后变 2，和其它 1 不等
      temp = t([{"wuxing/金", 1}, {"wuxing/木", 1}, {"wuxing/水", 1},
                {"wuxing/火", 1}, {"wuxing/土", 1}])

      assert {:allow, [{:set_temp, "wuxing/水", 2}]} = Wuxing.evaluate(temp, "north")
    end

    test "金木火土都是 2、水为 1 -> 往北后五行都是 2 -> 脱困" do
      temp = t([{"wuxing/金", 2}, {"wuxing/木", 2}, {"wuxing/水", 1},
                {"wuxing/火", 2}, {"wuxing/土", 2}])

      assert {:block, msg, effects} = Wuxing.evaluate(temp, "north")

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

      assert {:block, msg, effects} = Wuxing.evaluate(temp, "west")
      assert msg == "你掉进机关，落入僧监。"
      assert effects == [{:delete_prefix, "wuxing/"}, {:force_move, "shaolin:jianyu1"}]
    end

    test "即使 temp 为空也照样触发（机关不看计数）" do
      assert {:block, "你掉进机关，落入僧监。", _} = Wuxing.evaluate(%{}, "west")
    end
  end

  describe "往东/南：不触发" do
    test "两个方向都原样放行且无副作用" do
      temp = t([{"wuxing/金", 1}, {"wuxing/水", 1}])

      assert {:allow, []} = Wuxing.evaluate(temp, "east")
      assert {:allow, []} = Wuxing.evaluate(temp, "south")
    end

    test "即使五行已凑齐，东/南也不该脱困（脱困只由往北触发）" do
      temp = t([{"wuxing/金", 2}, {"wuxing/木", 2}, {"wuxing/水", 2},
                {"wuxing/火", 2}, {"wuxing/土", 2}])

      assert {:allow, []} = Wuxing.evaluate(temp, "east")
      assert {:allow, []} = Wuxing.evaluate(temp, "south")
    end
  end

  describe "不在 dirs 里的方向" do
    test "down 等交给 ::valid_leave，原样放行" do
      assert {:allow, []} = Wuxing.evaluate(%{}, "down")
      assert {:allow, []} = Wuxing.evaluate(%{}, "up")
      assert {:allow, []} = Wuxing.evaluate(%{}, "northeast")
    end
  end

  describe "复位后的完整走法（端到端，纯函数层面）" do
    test "往西中机关 -> 清零；再往北两次凑成 1 不脱困；五行齐了才脱困" do
      # 先被机关清空
      assert {:block, _, effects} = Wuxing.evaluate(%{"wuxing/金" => 5}, "west")

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
          {:allow, [{:set_temp, k, v}]} = Wuxing.evaluate(acc, "north")
          Map.put(acc, k, v)
        end)

      assert temp == %{"wuxing/水" => 2}
    end
  end
end
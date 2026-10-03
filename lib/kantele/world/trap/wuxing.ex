defmodule Kantele.World.Trap.Wuxing do
  @moduledoc """
  五行迷宫（`d/shaolin/wuxing0.c` ~ `wuxing4.c`）

  ## 每个房间的规则**不一样**

  上一版只读了 `wuxing0.c`，把五个房间一律当成「往北 +水 / 往西是机关」，
  结果只有水会被累加，**五行永远凑不齐、迷宫永远出不去**。

  逐个读 LPC 之后，真正的映射是：

  | 房间 | 递增方向 | 元素 | 机关方向 |
  |---|---|---|---|
  | `wuxing0` | north | 水 | west |
  | `wuxing1` | south | 火 | west |
  | `wuxing2` | east | 木 | north |
  | `wuxing3` | north | 土 | west |
  | `wuxing4` | west | 金 | north |

  五个房间的 `check_out/1` 完全一致（金木水火土相等且 > 0 就脱困）。

  ## 迷宫是个五环

      wuxing0 --north(水)--> wuxing2 --east(木)--> wuxing1
        ^                        |
        |                        v
      wuxing4 <--west(金)-- wuxing3 <--north(土)--
                        （wuxing1 --south(火)-->）

  沿「递增方向」走一圈，五行各 +1，第 5 步 `check_out` 成立 -> 从暗道
  `andao2` 脱困。而每个房间的机关方向都不在环上（wuxing2 / wuxing4 的机关
  是 north，正好挡在环的另一侧），所以「走错方向」就会掉进僧监。

  LPC 里 `dirs = ({"east","south","west","north"})`：在这四个方向之外的
  （如 `down`）直接交给 `::valid_leave`，不触发任何东西。
  """

  # room key -> {递增方向, 元素, 机关方向}
  # 来源：d/shaolin/wuxing{0..4}.c 各自的 valid_leave
  @rooms %{
    "wuxing0" => {"north", "水", "west"},
    "wuxing1" => {"south", "火", "west"},
    "wuxing2" => {"east", "木", "north"},
    "wuxing3" => {"north", "土", "west"},
    "wuxing4" => {"west", "金", "north"}
  }

  @dirs ~w(east south west north)
  @elements ~w(金 木 水 火 土)

  @escape_msg "你顺利地走出了五行迷宫。"
  @trap_msg "你掉进机关，落入僧监。"

  @doc """
  该房间的 `{递增方向, 元素, 机关方向}`；不是五行迷宫房间则返回 nil
  """
  def rule(room_key), do: Map.get(@rooms, room_key)

  @doc """
  `temp` + 房间 + 方向 -> `{:allow, effects}` | `{:block, msg, effects}`

  effects 是数据，交给 `Kantele.Character.TrapEvent` 执行：

    * `{:set_temp, key, value}`
    * `{:delete_prefix, prefix}` —— LPC `delete_temp("wuxing")`（删整棵子树）
    * `{:force_move, room_id}` —— LPC `me->move(...)`
  """
  def evaluate(temp, dir, room_key) do
    case Map.get(@rooms, room_key) do
      nil ->
        {:allow, []}

      {inc_dir, element, trap_dir} ->
        cond do
          dir not in @dirs ->
            # 不在 LPC 的 dirs 里（down 等）-> 交给 ::valid_leave
            {:allow, []}

          dir == trap_dir ->
            {:block, @trap_msg,
             [
               {:delete_prefix, "wuxing/"},
               {:force_move, "shaolin:jianyu1"}
             ]}

          dir == inc_dir ->
            # 递增该房间对应的五行，再判是否凑齐
            key = "wuxing/#{element}"
            count = temp_count(temp, element) + 1
            temp2 = Map.put(temp, key, count)

            if check_out?(temp2) do
              {:block, @escape_msg,
               [
                 {:set_temp, key, count},
                 {:delete_prefix, "wuxing/"},
                 {:force_move, "shaolin:andao2"}
               ]}
            else
              {:allow, [{:set_temp, key, count}]}
            end

          true ->
            # 环上另外两个方向：迷宫内的普通转向
            {:allow, []}
        end
    end
  end

  @doc """
  LPC `check_out/1`：五行计数全部相等且大于 0
  """
  def check_out?(temp) do
    values = Enum.map(@elements, &temp_count(temp, &1))
    [metal | _] = values

    metal > 0 and Enum.all?(values, &(&1 == metal))
  end

  @doc "五行清单（LPC 里的金木水火土）"
  def elements, do: @elements

  # LPC query_temp 对缺失键返回 0
  defp temp_count(temp, element) do
    case Map.get(temp, "wuxing/#{element}", 0) do
      n when is_integer(n) -> n
      _ -> 0
    end
  end
end
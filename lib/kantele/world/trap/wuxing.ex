defmodule Kantele.World.Trap.Wuxing do
  @moduledoc """
  五行迷宫（`d/shaolin/wuxing0.c` ~ `wuxing4.c`）

  LPC 原文：

      string* dirs = ({"east", "south", "west", "north"});

      int check_out(object me)
      {
          metal = me->query_temp("wuxing/金");
          wood  = me->query_temp("wuxing/木");
          water = me->query_temp("wuxing/水");
          fire  = me->query_temp("wuxing/火");
          earth = me->query_temp("wuxing/土");

          if ( metal > 0 &&
              metal == wood && metal == water &&
              metal == fire && metal == earth )
          {
              me->delete_temp("wuxing");
              me->move(__DIR__"andao2");
              return (1);
          }
          return (0);
      }

      int valid_leave(object me, string dir)
      {
          if (member_array(dir, dirs) != -1)
          {
              if (dir == "north")
              {
                  count = me->query_temp("wuxing/水");
                  count++;
                  me->set_temp("wuxing/水", count);
                  if (check_out(me))
                      return notify_fail("你顺利地走出了五行迷宫。\\n");
              }
              else if (dir == "west")
              {
                  me->delete_temp("wuxing");
                  me->move(__DIR__"jianyu1");
                  return notify_fail("你掉进机关，落入僧监。\\n");
              }
          }
          return ::valid_leave(me, dir);
      }

  语义：**只能一直往北走**，每往北一次把「水」计数 +1；一旦金木水火土
  五行计数全部相等且大于 0，就从暗道（andao2）脱困并清空计数。
  往西则触发机关掉进僧监（jianyu1），计数清空 —— 也就是「走错就重置」。
  东 / 南 只是普通出口（迷宫里是死路转出口）。

  注意 `query_temp` 对缺失键返回 0，所以「从没往北走过」时 metal = 0，
  `metal > 0` 不成立 —— 必须至少往北走过一次。
  """

  @dirs ~w(east south west north)
  @elements ~w(金 木 水 火 土)

  @north_count_msg "你顺利地走出了五行迷宫。"
  @west_trap_msg "你掉进机关，落入僧监。"

  @doc """
  `temp` -> `{:allow, effects}` | `{:block, msg, effects}`

  effects 是数据，交给 `Kantele.Character.TrapEvent` 执行：

    * `{:set_temp, key, value}`
    * `{:delete_prefix, prefix}` —— 对应 LPC `delete_temp("wuxing")`
      （删掉整个子树，不是单个键）
    * `{:force_move, room_id}` —— 对应 LPC `me->move(...)`
  """
  def evaluate(temp, dir) do
    cond do
      dir not in @dirs ->
        # 不在 dirs 里（down 等）-> 交给 ::valid_leave，正常放行
        {:allow, []}

      dir == "west" ->
        {:block, @west_trap_msg,
         [
           {:delete_prefix, "wuxing/"},
           {:force_move, "shaolin:jianyu1"}
         ]}

      dir == "north" ->
        count = temp_count(temp, "水") + 1
        set = {:set_temp, "wuxing/水", count}
        temp2 = Map.put(temp, "wuxing/水", count)

        if check_out?(temp2) do
          {:block, @north_count_msg,
           [
             set,
             {:delete_prefix, "wuxing/"},
             {:force_move, "shaolin:andao2"}
           ]}
        else
          {:allow, [set]}
        end

      true ->
        # east / south：迷宫内的普通转向，不触发任何东西
        {:allow, []}
    end
  end

  @doc """
  LPC `check_out/1`：五行计数全部相等且大于 0。

  单独暴露是为了能直接单测这个判定（它决定「是否脱困」）。
  """
  def check_out?(temp) do
    values = Enum.map(@elements, &temp_count(temp, &1))
    [metal | _] = values

    metal > 0 and Enum.all?(values, &(&1 == metal))
  end

  # LPC query_temp 对缺失键返回 0
  defp temp_count(temp, element) do
    case Map.get(temp, "wuxing/#{element}", 0) do
      n when is_integer(n) -> n
      _ -> 0
    end
  end
end
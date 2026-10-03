defmodule Kantele.World.Trap do
  @moduledoc """
  带副作用的出口陷阱（LPC 里那几个不是纯谓词的自定义函数）

  `Kantele.World.LpcCondition` 是**纯判定**：`check/2` 只返回
  `{:block, msg}` / `:allow`，房间进程也改不了玩家 meta。但 LPC 的
  valid_leave 里有三类函数会改玩家状态并强制传送：

    - `check_out(me)`    d/shaolin/wuxing*.c 五行迷宫（5 个房间）
    - `check_dirs(me,dir)`  d/shaolin/bagua*.c 八卦阵（8 个房间）
    - `ob->refuse(me)`   d/city/underlt.c 擂台（5 个房间）

  它们被 `LpcCondition.enforceable?/1` 判为不可执行，条件原文保留、**不拦** ——
  于是一律 fail-open，陷阱完全不生效（见 docs/ucl-comment-todo.zh-CN.md 四、C）。

  这里把「判定」和「副作用」拆开：

    * `evaluate/3` **纯函数**：只读玩家的 temp，算出该走哪些副作用，返回
      `{:allow, effects}` 或 `{:block, msg, effects}`。房间进程调用它。
    * effects 是**数据**，由 `Kantele.World.Room.TrapEffectEvent` 下发给角色进程
      去真正改 meta / 扣血 / 传送（`Kantele.Character.TrapEvent`）。

  为什么不直接在房间进程里改：meta 只有角色进程能安全地改并落盘
  （`Kantele.Character.Records.save/1`）。而房间进程**已经能读到玩家的
  meta** —— `movement_request` 的 `event.data.character` 就是完整角色，
  `check_guarders` 一直这么用。所以「读」放房间、「写」放角色，
  不需要同步 GenServer 调用（那会有死锁风险）。

  ## 与 LPC 的一个重要差异

  转换器把 `valid_leave` 里除自定义函数以外的逻辑**整段丢了**。例如
  `wuxing.c` 真实代码是：

      if (dir == "north") { count = query_temp("wuxing/水") + 1;
                            set_temp("wuxing/水", count);
                            if (check_out(me)) return notify_fail("你顺利地走出了五行迷宫。\\n"); }
      else if (dir == "west") { delete_temp("wuxing"); move(jianyu1);
                                 return notify_fail("你掉进机关，落入僧监。\\n"); }

  UCL 里只剩 `condition = "check_out(me)"` 一条 —— north 的计数和 west 的陷阱
  都不见了。所以本模块移植的是**整个 valid_leave**，不是那个谓词本身。
  """

  alias Kantele.World.Trap.Wuxing

  @doc """
  房间 + 移动者 + 方向 -> `{:allow, effects}` | `{:block, msg, effects}`

  `vetoes` 是该房间的 valid_leave 列表；只挑出「陷阱型」条件来跑。
  """
  def dispatch(vetoes, mover_meta, dir, room_id) when is_list(vetoes) do
    Enum.reduce_while(vetoes, {:allow, []}, fn veto, acc ->
      case acc do
        {:block, _, _} ->
          {:halt, acc}

        {:allow, effects_so_far} ->
          case trap_condition(veto) do
            nil ->
              {:cont, acc}

            kind ->
              case run(kind, mover_meta, dir, room_id) do
                {:allow, effects} -> {:cont, {:allow, effects_so_far ++ effects}}
                {:block, msg, effects} -> {:halt, {:block, msg, effects_so_far ++ effects}}
              end
          end
      end
    end)
  end

  # 识别「陷阱型」条件。**按条件原文识别**，所以不需要给房间加新字段，
  # 也不用改 data/world —— 那些条件原文一直保留着，只是以前被 enforceable? 挡掉了。
  defp trap_condition(veto) do
    case Map.get(veto, :condition) do
      c when is_binary(c) ->
        cond do
          String.contains?(c, "check_out(") -> :wuxing
          # check_dirs(me,dir) 八卦阵：等 Trap.Bagua 落地后再加
          true -> nil
        end

      _ ->
        nil
    end
  end

  defp run(:wuxing, mover_meta, dir, room_id),
    do: Wuxing.evaluate(Map.get(mover_meta, :temp) || %{}, dir, room_key(room_id))

  # 五行迷宫每个房间的规则不同（递增哪个元素、在哪个方向、机关在哪），
  # 所以必须知道**具体是哪个房间**，不能只拿 dir。
  # "shaolin:wuxing0" -> "wuxing0"。只取最后一段：五行迷宫的规则表是按
  # 房间 key 建的。之前写成两个子句（`":" <> _ = room_id` 那条并没有真正匹配上，
  # 落到了 is_binary 那条把整个 id 原样返回），于是查表全部落空、陷阱静默失效。
  defp room_key(room_id) when is_binary(room_id),
    do: room_id |> String.split(":") |> List.last()

  defp room_key(_), do: nil
end
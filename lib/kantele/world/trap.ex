defmodule Kantele.World.Trap do
  @moduledoc """
  带副作用的出口陷阱（LPC 里那几个不是纯谓词的自定义函数）

  `Kantele.World.LpcCondition` 是**纯判定**：`check/2` 只返回
  `{:block, msg}` / `:allow`，房间进程也改不了玩家 meta。但 LPC 的
  valid_leave 里有三类函数会改玩家状态并强制传送：

    - `check_out(me)`    d/shaolin/wuxing*.c 五行迷宫（5 个房间）
    - `check_dirs(me,dir)`  d/shaolin/bagua.h 八卦阵（8 个房间，共享头文件、规则一致）
    - `ob->refuse(me)`   d/city/underlt.c 擂台（5 个房间，4 个可达）

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

  只挑出该房间 valid_leave 里的「陷阱型」条件来跑。

  `mover` 传的是**完整角色**（不只 meta）：`ob->refuse(me)` 要读
  `attributes["wiz_level"]` 判断巫师，而那个字段不在 meta 上。
  """
  def dispatch(room, mover, dir) do
    dispatch(Map.get(room, :exit_vetoes) || [], room, mover, dir)
  end

  defp dispatch(vetoes, room, mover, dir) when is_list(vetoes) do
    Enum.reduce_while(vetoes, {:allow, []}, fn veto, acc ->
      case acc do
        {:block, _, _} ->
          {:halt, acc}

        {:allow, effects_so_far} ->
          case trap_condition(veto) do
            nil ->
              {:cont, acc}

            kind ->
              case run(kind, room, mover, dir) do
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
          String.contains?(c, "check_dirs(") -> :bagua
          String.contains?(c, "->refuse(") -> :arena
          true -> nil
        end

      _ ->
        nil
    end
  end

  defp run(:wuxing, room, mover, dir),
    do: Wuxing.evaluate(temp_of(mover), dir, room_key(Map.get(room, :id)))

  # 八卦阵的规则八个房间一致（bagua.h 是共享头文件），所以不需要 room_key。
  defp run(:bagua, _room, mover, dir),
    do: Kantele.World.Trap.Bagua.evaluate(temp_of(mover), dir)

  #  ob->refuse(me)：LPC 里 ob 是**目标房间**（find_object(dest)），
  #  只有它定义了 refuse() 才会拒绝。这里用「目标房间有没有关闭状态」来判定，
  #  等价且不硬编码房间 id。
  defp run(:arena, room, mover, dir) do
    Kantele.World.Arena.refuse(dest_room_id(room, dir), wizard?(mover))
  end

  defp temp_of(mover), do: Map.get(Map.get(mover, :meta) || %{}, :temp) || %{}

  # wiz_level 存在 character.attributes 上，不在 meta 里 —— 所以这里必须收
  # 完整的角色。模块是 `Kantele.Admin.Access`，函数名 `wizardp/1`（LPC 的
  # wizardp()），不是 `Kantele.Access.wizard?`（那个模块/函数不存在，
  # 但 Elixir 对未知的远程调用只在编译期给警告，很容易漏掉）。
  defp wizard?(mover) do
    Kantele.Admin.Access.wizardp(mover)
  end

  # 这次移动的目标房间 id；没有这个方向就是 nil（放行）
  defp dest_room_id(room, dir) do
    room
    |> Map.get(:exits, [])
    |> Enum.find_value(fn e -> if Map.get(e, :exit_name) == dir, do: Map.get(e, :end_room_id) end)
  end

  # 五行迷宫每个房间的规则不同（递增哪个元素、在哪个方向、机关在哪），
  # 所以必须知道**具体是哪个房间**，不能只拿 dir。
  # "shaolin:wuxing0" -> "wuxing0"。只取最后一段：五行迷宫的规则表是按
  # 房间 key 建的。之前写成两个子句（`":" <> _ = room_id` 那条并没有真正匹配上，
  # 落到了 is_binary 那条把整个 id 原样返回），于是查表全部落空、陷阱静默失效。
  defp room_key(room_id) when is_binary(room_id),
    do: room_id |> String.split(":") |> List.last()

  defp room_key(_), do: nil
end
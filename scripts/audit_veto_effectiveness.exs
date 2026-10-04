# 出口拦截条件**实际生效性**审计
#
#   mix run --no-start scripts/audit_veto_effectiveness.exs
#
# `data/world` 里有 166 条 valid_leave 条件，但「写在数据里」不等于「会拦人」。
# 一条条件要真的拦下玩家，必须同时满足：
#
#   1. 限定了方向（`dir == 'x'`）—— 否则等于把该房间**所有**出口都变成同一道门禁，
#      玩家可能被永久拦在房里，所以未限定的条件一律不执行
#   2. 那个方向**真实存在**（否则永远匹配不上）
#   3. 依赖的 NPC / 物品**有定义且在房间里**（`objectp(present('x', ...))`）
#   4. 求值器支持它（`supported?` + `enforceable?`）
#
# 另有三类走 Trap 通道（不是纯判定）：
#   check_out(me)   -> Trap.Wuxing   （五行迷宫，5 个房间）
#   check_dirs(...) -> Trap.Bagua    （八卦阵，8 个房间）
#   ob->refuse(me)  -> Trap.Arena    （擂台，5 个房间）
#
# 这份清单的意义：**避免再次出现「以为做了、其实没生效」**。
# 之前的 guarded_exit 守卫（meta.guardert.family 全是 nil）、
# 这次的性别条件（NPC 不在场），都是同一类沉默失效。

alias Kantele.World.{Loader, LpcCondition}

world = Loader.load()

# Regex.scan 的返回形状随 capture 选项而变，统一成一个函数取出所有捕获组
cap = fn re, text ->
  Regex.scan(re, text, capture: :all_but_first)
  |> Enum.flat_map(fn
    [] -> []
    [x | _] -> List.wrap(x)
  end)
  |> Enum.map(&to_string/1)
end

# ---------- 收集所有 NPC / 物品的别名 ----------

parse_aliases = fn body ->
  cap.(~r/aliases\s*=\s*\[(.*?)\]/s, body)
  |> case do
    [al | _] ->
      cap.(~r/"([^"]+)"/, al) |> MapSet.new()

    _ ->
      MapSet.new()
  end
end

definitions =
  for f <- Path.wildcard("data/world/*.ucl"), reduce: MapSet.new() do
    acc ->
      t = File.read!(f)

      cap.(~r/(?:characters|items)\s+"[^"]+"\s*\{(.*?)\n\s*\}/s, t)
      |> Enum.reduce(acc, fn body, a -> MapSet.union(a, parse_aliases.(body)) end)
  end

IO.puts("已定义 NPC/物品别名: #{MapSet.size(definitions)}")

# ---------- 某房间在场的 NPC 别名 ----------

room_occupants = fn room_id, zone_id ->
  path = "data/world/#{zone_id}.ucl"

  if File.exists?(path) do
    key = String.replace_prefix(room_id, zone_id <> ":", "")
    t = File.read!(path)

    body =
      case cap.(~r/room_characters\s+"#{Regex.escape(key)}"\s*\{(.*?)\n\s*\}/s, t) do
        [b | _] -> b
        _ -> ""
      end

    ids = cap.(~r/characters\.(\w+)\.id/, body)

    ids
    |> Enum.uniq()
    |> Enum.reduce(MapSet.new(), fn cid, acc ->
      case cap.(~r/characters\s+"#{Regex.escape(cid)}"\s*\{(.*?)\n\s*\}/s, t) do
        [cb | _] -> MapSet.union(acc, parse_aliases.(cb))
        _ -> acc
      end
    end)
  end
end

# ---------- 条件种类 ----------

kind_of = fn c ->
  cond do
    String.contains?(c, "check_out(") -> {:trap, :wuxing}
    String.contains?(c, "check_dirs(") -> {:trap, :bagua}
    String.contains?(c, "->refuse(") -> {:trap, :arena}
    true -> {:pure, :cond}
  end
end

dirs_of = fn c -> cap.(~r/dir\s*==\s*'(\w+)'/, c) end

# 别名可以带空格（'liu chuxuan'），而且原文里单双引号混用，
# 所以走解析器而不是正则 —— 正则会在 `present("x", ...)` 上漏掉。
presents_of = fn c -> LpcCondition.present_refs(c) end


# `present(x, environment(me))` / `present(x, this_object())` 要求目标**在场**；
# `present(x, me)` 是「玩家自己身上」，只需要物品有定义（玩家捡到就能用）。
# 脚本里没有模块作用域，defp 用不了，所以写成匿名函数。
room_ref? = fn alias, cond ->
  re = ~r/present\('#{Regex.escape(alias)}'\s*,\s*([^)]+)\)/
  case Regex.run(re, cond) do
    [_, second] -> second =~ "environment" or second =~ "this_object"
    _ -> false
  end
end

# ---------- 逐条判定 ----------

results =
  for room <- world.rooms,
      veto <- room.exit_vetoes,
      c = Map.get(veto, :condition),
      is_binary(c) and c != "" do
    {kind, sub} = kind_of.(c)
    exits = Enum.map(room.exits, & &1.exit_name)
    req = dirs_of.(c)
    presents = presents_of.(c)
    missing_dirs = Enum.reject(req, &(&1 in exits))

    {status, reason} =
      cond do
        # ---------- Trap 通道 ----------
        kind == :trap ->
          cond do
            missing_dirs != [] ->
              {:dead, "要求不存在的方向 #{inspect(missing_dirs)}"}

            sub == :arena ->
              {:live, "Trap.Arena（擂台关闭且非巫师时拦）"}

            true ->
              {:live, "Trap.#{sub}"}
          end

        # ---------- 纯条件 ----------
        not LpcCondition.direction_scoped?(c) ->
          {:dead, "未限定方向（执行会把该房所有出口变成同一道门禁）"}

        not LpcCondition.supported?(c) ->
          {:dead, "依赖运行时缺失的字段"}

        not LpcCondition.enforceable?(c) ->
          {:dead, "求值器处理不了（缺自定义函数 / 链式调用等）"}

        missing_dirs != [] ->
          {:dead, "要求不存在的方向 #{inspect(missing_dirs)}"}

        presents == [] ->
          {:live, "纯条件"}

        true ->
          in_room = room_occupants.(room.id, room.zone_id)

          # `present(x, me)` 是「玩家身上有没有」，`present(x, environment(me))`
          # 才是「房间里有没有」—— 两者判据不同：
          #   * 玩家身上的（多半是物品）只要**有定义**就够了，玩家捡到就能用，
          #     不该因为「不在房间里」判成 dead
          #   * 房间里的必须在 room_characters 里
          # present() 的第二个参数在原文里是 me / environment(me) / this_object()
          # 这里按「是否含 environment 或 this_object」判断是否要求在场
          on_player = Enum.filter(presents, fn a -> not room_ref?.(a, c) end)
          in_room_refs = Enum.filter(presents, fn a -> room_ref?.(a, c) end)

          undefined_player = Enum.reject(on_player, &MapSet.member?(definitions, &1))
          undefined_room = Enum.reject(in_room_refs, &MapSet.member?(definitions, &1))
          not_placed = Enum.reject(in_room_refs, &MapSet.member?(in_room, &1))

          # 每个 present() 别名此刻「找不找得到」：
          #   * 玩家身上的 -> 有定义即可
          #   * 房间里的   -> 有定义**且**在 room_characters 里
          # 然后交给 LpcCondition.satisfiable?/2 按 &&/||/! 的真实布尔结构判定：
          # LPC 里大量条件是析取（`present('fumo dao',me) || present('jingang zhao',me)`），
          # 一律当合取会把「其实有效」的门禁误判成 dead。
          avail =
            Map.new(presents, fn a ->
              defined? = MapSet.member?(definitions, a)

              {a,
               if room_ref?.(a, c) do
                 defined? and MapSet.member?(in_room, a)
               else
                 defined?
               end}
            end)

          cond do
            LpcCondition.satisfiable?(c, avail) ->
              {:live, "纯条件"}

            undefined_player != [] ->
              {:dead, "玩家身上要带的物品未定义 #{inspect(undefined_player)}"}

            undefined_room != [] ->
              {:dead, "依赖的 NPC/物品未定义 #{inspect(undefined_room)}"}

            not_placed != [] ->
              {:dead, "依赖的 NPC 不在房里 #{inspect(not_placed)}"}

            true ->
              {:live, "纯条件"}
          end
      end

    %{room: room.id, cond: c, kind: kind, status: status, reason: reason}
  end

live = Enum.filter(results, &(&1.status == :live))
dead = Enum.filter(results, &(&1.status == :dead))

IO.puts("")
IO.puts("出口拦截条件生效性审计")
IO.puts(String.duplicate("=", 78))
IO.puts("条件总数: #{length(results)}")
IO.puts("  会拦人: #{length(live)}")
IO.puts("  不会拦 : #{length(dead)}")

IO.puts("")
IO.puts("=== 不会拦的，按原因分组 ===")

dead
|> Enum.group_by(& &1.reason)
|> Enum.sort_by(fn {_, items} -> -length(items) end)
|> Enum.each(fn {reason, items} ->
  IO.puts("")
  IO.puts("  [#{length(items)} 条] #{reason}")
  Enum.each(items, fn r -> IO.puts("      #{r.room}  #{String.slice(r.cond, 0, 60)}") end)
end)

IO.puts("")
IO.puts("=== 会拦人的（#{length(live)} 条）===")

live
|> Enum.group_by(& &1.reason)
|> Enum.sort_by(fn {_, items} -> -length(items) end)
|> Enum.each(fn {reason, items} ->
  IO.puts("")
  IO.puts("  [#{length(items)} 条] #{reason}")
  Enum.each(items, fn r -> IO.puts("      #{r.room}  #{String.slice(r.cond, 0, 60)}") end)
end)
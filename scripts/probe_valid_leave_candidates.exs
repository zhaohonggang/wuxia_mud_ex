# P4 候选条件分类探针（真实门槛）
#
#   MSYS_NO_PATHCONV=1 docker exec -w /app wuxia_mud_dev-app-1 \
#     mix run --no-start scripts/probe_valid_leave_candidates.exs
#
# survey_valid_leave.py 从 LPC 源抽出候选后，先经过本探针用**运行时真门**
# 分类一遍，只有全部通过的候选才允许回填：
#
#   1. `LpcCondition.parse/1` 能解析（词法/语法）
#   2. `enforceable?/1`  AST 形态求值器认识
#   3. `supported?/1`    不依赖运行时拿不到的数据
#   4. `direction_scoped?/1` 或数据侧显式 `all_dirs = true`
#      （否则照原样执行会把该房所有出口变成同一道门禁）
#   5. 方向真实存在于该房 exits（direction = "~" 除外——条件自身限定）
#   6. `present('x')` 引用的别名在 data/world 里有定义（NPC/物品）
#   7. 消息非空、无 elias 敌意字符
#   8. 不与同房既有**生效**条目撞车（同方向同消息 = 被遮蔽，回填无意义）
#
# 任何一条不过 → 该候选留作 Trap / 后续批次，绝不写入。

alias Kantele.World.{Loader, LpcCondition}

world = Loader.load()

{:ok, raw} = File.read("tmp/p4_candidates.json")
{:ok, data} = Jason.decode(raw)

new_cands = Enum.filter(data["candidates"], fn c -> not c["already_present"] end)

IO.puts("候选总数 #{length(data["candidates"])}，其中新增 #{length(new_cands)} 条\n")

# ---------- 全库已定义别名（NPC/物品） ----------

cap = fn re, text ->
  Regex.scan(re, text, capture: :all_but_first)
  |> Enum.flat_map(fn
    [] -> []
    [x | _] -> List.wrap(x)
  end)
  |> Enum.map(&to_string/1)
end

alias_of = fn body ->
  case cap.(~r/aliases\s*=\s*\[(.*?)\]/s, body) do
    [al | _] -> cap.(~r/"([^"]+)"/, al) |> MapSet.new()
    _ -> MapSet.new()
  end
end

defined_aliases =
  for f <- Path.wildcard("data/world/*.ucl"), reduce: MapSet.new() do
    acc ->
      body_text = File.read!(f)

      cap.(~r/(?:characters|items)\s+"[^"]+"\s*\{(.*?)\n\s*\}/s, body_text)
      |> Enum.reduce(acc, fn body, a -> MapSet.union(a, alias_of.(body)) end)
  end

IO.puts("已定义 NPC/物品别名: #{MapSet.size(defined_aliases)}\n")

# ---------- 房间索引 ----------

room_by_id =
  for room <- world.rooms, into: %{} do
    {room.id, room}
  end

verdicts =
  for c <- new_cands do
    zone = c["zone"]
    room_key = c["room"]
    # Loader 的 room.id 形如 "zone:room"
    room = room_by_id["#{zone}:#{room_key}"]
    cond_str = c["condition"]
    msg = c["message"]
    direction = c["direction"]

    exits = if room, do: Enum.map(room.exits, & &1.exit_name), else: []
    existing = if room, do: room.exit_vetoes, else: []

    parse_ok? = match?({:ok, _}, LpcCondition.parse(cond_str))
    enforceable? = LpcCondition.enforceable?(cond_str)
    supported? = LpcCondition.supported?(cond_str)
    all_dirs? = c["all_dirs"] == true
    dir_scoped? = LpcCondition.direction_scoped?(cond_str)

    dir_ok? =
      cond do
        direction == "~" -> true
        direction in exits -> true
        true -> false
      end

    presents = LpcCondition.present_refs(cond_str)
    missing_aliases = Enum.reject(presents, &(&1 in defined_aliases))

    msg_ok? = is_binary(msg) and String.length(msg) > 0 and not String.contains?(msg, "[")

    # 与既有**生效**条目撞车：同方向 + 同消息 + 有条件（既有的无条件条目
    # condition 为 nil，运行时本来就跳过，不算遮蔽；loader 把 "~"/nil 归一
    # 成 "*"，这里同步归一再比）
    norm_dir = fn d -> if d in [nil, "~"], do: "*", else: d end

    shadowed? =
      Enum.any?(existing, fn v ->
        is_binary(Map.get(v, :condition)) and
          Map.get(v, :condition) != "" and
          norm_dir.(Map.get(v, :direction)) == norm_dir.(direction) and
          Map.get(v, :message) == msg
      end)

    checks = [
      {"parse", parse_ok?},
      {"enforceable", enforceable?},
      {"supported", supported?},
      {"dir-scoped-or-all_dirs", all_dirs? or dir_scoped?},
      {"room-found", room != nil},
      {"dir-exists", dir_ok?},
      {"present-aliases-defined", missing_aliases == []},
      {"message-ok", msg_ok?},
      {"not-shadowed", not shadowed?}
    ]

    failed = for {name, ok?} <- checks, not ok?, do: name

    status = if failed == [], do: :effective, else: :blocked

    {status, c, failed, missing_aliases, exits}
  end

eff = Enum.filter(verdicts, fn {s, _, _, _, _} -> s == :effective end)
blk = Enum.filter(verdicts, fn {s, _, _, _, _} -> s == :blocked end)

IO.puts("=== 可回填（#{length(eff)} 条）===")

for {:effective, c, _f, _m, _e} <- eff do
  IO.puts("  #{c["zone"]}/#{c["room"]}  dir=#{c["direction"]} all_dirs=#{c["all_dirs"]}")
  IO.puts("    #{c["condition"]}")
  IO.puts("    msg: #{String.slice(c["message"], 0, 40)}")
end

if blk != [] do
  IO.puts("\n=== 拦截（#{length(blk)} 条，留 Trap/后续）===")

  for {:blocked, c, failed, missing, _e} <- blk do
    IO.puts("  #{c["zone"]}/#{c["room"]}  #{inspect(failed)}")

    if missing != [] do
      IO.puts("    缺失别名: #{inspect(missing)}")
    end

    IO.puts("    #{c["condition"]}")
  end
end

IO.puts(
  "\n汇总: effective=#{length(eff)} blocked=#{length(blk)} " <>
    "(M7 生效基数 133，回填后预期 133+#{length(eff)})"
)

# 机器可读结论：回填脚本只写 effective 名单里的条目
verdict =
  %{
    effective:
      for({:effective, c, _f, _m, _e} <- eff, do: %{
        zone: c["zone"],
        room: c["room"],
        condition: c["condition"],
        message: c["message"],
        direction: c["direction"],
        all_dirs: c["all_dirs"],
        source: c["source"],
        lpc_line: c["lpc_line"]
      }),
    blocked:
      for({:blocked, c, failed, _m, _e} <- blk, do: %{
        zone: c["zone"],
        room: c["room"],
        condition: c["condition"],
        failed: failed
      })
  }

File.mkdir_p!("tmp")
File.write!("tmp/p4_verdict.json", Jason.encode!(verdict, pretty: true))
IO.puts("wrote tmp/p4_verdict.json")

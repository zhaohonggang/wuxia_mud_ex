# P0a 迁移：把能解析的 vendor_goods 注释变成真实 goods 条目。
#
# 逐条 `# vendor_goods: "<path>" (file not found)` 分类：
#   A. 同区，目标区已有该 items 产物 -> `{ id = items.<名>.id }`
#   B. 跨区，目标区已有该 items 产物 -> `{ id = <区>.items.<名>.id }`
#      （loader.dereference 首段非 items/rooms/characters 时按 zone id 解析）
#   C. 目标区无产物 / 非转换区 / /clone 目标 -> 保留注释（本脚本不动）
#
# 块内改写：以 NPC 块为单位局部重建（避免全局行号漂移）
#   - 已有 `goods = [ ... ]`：新条目去重后追加到块尾
#   - 无 goods 块：在首个被消费注释处新建 `goods = [ ... ]`
#   - 被消费的注释删除；未消费注释原样保留
#
# 用法：
#   VENDOR_GO=1 mix run --no-start scripts/migrate_vendor_goods.exs            只统计
#   VENDOR_GO=1 VENDOR_APPLY=1 mix run --no-start scripts/migrate_vendor_goods.exs   写盘

defmodule VendorGoodsMigration do
  @comment ~r/^\s*#\s*(?:vendor_goods|goods):\s*"([^"]+)"\s*\(file not found\)\s*$/
  @char ~r/^(\s*)characters\s+"([^"]+)"\s*\{\s*$/
  @goods_open ~r/^(\s*)goods\s*=\s*\[\s*$/
  @entry ~r/^\s*\{ id = (.+?) \},?\s*$/

  def indent_of(line),
    do: String.length(line) - String.length(String.trim_leading(line))

  # 兼容 Elixir 1.11 的切片：0-based 闭区间 [a, b]；b 为负表示相对末尾
  def sl(list, a, b) do
    n = length(list)
    last = if b < 0, do: n + b + 1, else: min(b, n - 1)

    cond do
      a >= n -> []
      last < a -> []
      true -> Enum.slice(list, a, last - a + 1)
    end
  end

  @doc "把一行里的字符串内容与 # 注释清空，只留下结构字符（用于算花括号深度）"
  def skeleton(line) do
    line
    |> String.to_charlist()
    |> do_skeleton(false, [])
    |> Enum.reverse()
    |> List.to_string()
  end

  defp do_skeleton([], _in_string, acc), do: acc
  # 字符串外遇 # -> 行注释，直接丢弃余下
  defp do_skeleton([?# | _], false, acc), do: acc
  # 字符串内
  defp do_skeleton([?\\, _c, _n | rest], true, acc), do: do_skeleton(rest, true, [" " | [" " | acc]])
  defp do_skeleton([?" | rest], true, acc), do: do_skeleton(rest, false, [" " | acc])
  defp do_skeleton([c | rest], true, acc), do: do_skeleton(rest, true, [c | acc])
  # 字符串外
  defp do_skeleton([?" | rest], false, acc), do: do_skeleton(rest, true, [" " | acc])
  defp do_skeleton([c | rest], false, acc), do: do_skeleton(rest, false, [c | acc])

  defp delta(line) do
    s = skeleton(line)
    open = s |> :binary.matches("{") |> length()
    close = s |> :binary.matches("}") |> length()
    open - close
  end

  @doc "各区 items 产物名索引"
  def index_zone_items(world_dir) do
    world_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".ucl"))
    |> Map.new(fn file ->
      keys =
        (Path.join(world_dir, file)
         |> File.read!()
         |> String.split("\n")
         |> Enum.flat_map(fn line ->
           case Regex.run(~r/^\s*items\s+"([^"]+)"\s*\{/, line) do
             [_, name] -> [name]
             _ -> []
           end
         end))
        |> MapSet.new()

      {Path.rootname(file), keys}
    end)
  end

  # 原 LPC 的 /clone 下的物件在 mud/d 转换中无处落放，P0c 已集中搬到
  # clone_lib 区（见 scripts/build_missing_items.py），引用写成跨区形式。
  @clone_zone "clone_lib"

  @doc "路径 -> {目标区, items 名}；非 /d 目标返回 nil（镜像 room_id_from_path）"
  def resolve_path(path) do
    base =
      path
      |> String.replace(~r/__DIR__"/, "")
      |> String.replace(~r/"$/, "")
      |> String.replace(~r/^"\/d\//, "")
      |> String.replace("\\", "/")
      |> String.trim()

    # items 名归一必须与 LPCConverter.room_id_from_path 一致：
    # basename 去扩展名 -> `-` 换 `_` -> 小写。
    # 少了这一步，`/d/hengyang/yueqi/qin-jueyin` 就找不到 items "qin_jueyin"。
    norm = fn name ->
      name
      |> String.replace("-", "_")
      |> String.downcase()
    end

    cond do
      match = Regex.run(~r{^/d/([^/]+)/.*/([^/.]+)$}, base) ->
        [_, zone, name] = match
        {zone, norm.(name)}

      match = Regex.run(~r{^/clone/.*/([^/.]+)$}, base) ->
        [_, name] = match
        {@clone_zone, norm.(name)}

      true ->
        nil
    end
  end

  @doc "按花括号深度找出所有 top-level NPC 块：{起始行号, 结束行号, 名}"
  def npc_blocks(lines) do
    {_, _, blocks} =
      Enum.reduce(Enum.with_index(lines, 1), {0, nil, []}, fn {line, i}, {depth, pending, acc} ->
        next = depth + delta(line)
        opens? = depth == 0 and Regex.match?(@char, line)

        cond do
          opens? ->
            [_all, _ind, name] = Regex.run(@char, line)
            {next, {i, name}, acc}

          pending != nil and next == 0 ->
            {start, name} = pending
            {next, nil, [{start, i, name} | acc]}

          true ->
            {next, pending, acc}
        end
      end)

    Enum.reverse(blocks)
  end

  @doc "条目行：与既有 goods 块风格一致（带尾逗号，末项无逗号）"
  defp entry_lines([], _entry_line), do: []

  defp entry_lines(refs, entry_line) do
    refs
    |> Enum.map(fn ref -> entry_line.(ref) <> "," end)
    |> List.update_at(-1, &String.replace_suffix(&1, ",", ""))
  end

  @doc "重建单个 NPC 块：返回 {新块行, 统计, 保留的注释路径}"
  def rebuild_block(block_lines, zone, zone_items) do
    base = %{same: 0, cross: 0, kept: 0, added: 0, created: false, merged: false}

    goods_open =
      block_lines
      |> Enum.with_index()
      |> Enum.find_value(fn {line, i} -> if Regex.match?(@goods_open, line), do: i end)

    goods_close =
      case goods_open do
        nil ->
          nil

        open ->
          block_lines
          |> Enum.drop(open + 1)
          |> Enum.with_index(open + 1)
          |> Enum.find_value(fn {line, j} -> if String.trim(line) == "]", do: j end)
      end

    plan =
      block_lines
      |> Enum.with_index()
      |> Enum.map(fn {line, i} ->
        case Regex.run(@comment, line) do
          [_all, path] ->
            case resolve_path(path) do
              {target_zone, item} ->
                if MapSet.member?(Map.get(zone_items, target_zone, MapSet.new()), item) do
                  ref =
                    if target_zone == zone,
                      do: "items.#{item}.id",
                      else: "#{target_zone}.items.#{item}.id"

                  {:comment, i, ref, target_zone == zone, path}
                else
                  {:keep_comment, i, path}
                end

              nil ->
                {:keep_comment, i, path}
            end

          _ ->
            {:line, i, line}
        end
      end)

    new_refs =
      plan
      |> Enum.flat_map(fn
        {:comment, _i, ref, _same, _p} -> [ref]
        _ -> []
      end)
      |> Enum.uniq()

    same_n = Enum.count(plan, &match?({:comment, _, _, true, _}, &1))
    cross_n = Enum.count(plan, &match?({:comment, _, _, false, _}, &1))
    kept_paths = for {:keep_comment, _i, p} <- plan, do: p

    if new_refs == [] do
      {block_lines, %{base | kept: length(kept_paths)}, kept_paths}
    else
      consumed = for {:comment, i, _r, _s, _p} <- plan, do: i
      entry_line = fn ref -> "    { id = #{ref} }" end
      new_lines = fn refs -> entry_lines(refs, entry_line) end

      {out, added_now, action} =
        case goods_open do
          nil ->
            # 无 goods 块：在首个被消费注释处新建
            at = Enum.min(consumed)
            block = ["  goods = ["] ++ new_lines.(new_refs) ++ ["  ]"]

            out =
              block_lines
              |> Enum.with_index()
              |> Enum.flat_map(fn {line, i} ->
                cond do
                  i == at -> block
                  i in consumed -> []
                  true -> [line]
                end
              end)

            {out, length(new_refs), :created}

          open ->
            close = goods_close || length(block_lines)

            existing =
              block_lines
              |> sl(open + 1, close - 1)
              |> Enum.flat_map(fn line ->
                case Regex.run(@entry, line) do
                  [_all, ref] -> [ref]
                  _ -> []
                end
              end)

            add = Enum.reject(new_refs, &(&1 in existing))

            last_entry =
              block_lines
              |> Enum.with_index()
              |> Enum.filter(fn {_l, i} -> i > open and i < close end)
              |> Enum.reduce(nil, fn {l, i}, acc ->
                if Regex.match?(@entry, l), do: i, else: acc
              end)

            new_lines =
              add
              |> new_lines.()

            out =
              block_lines
              |> Enum.with_index()
              |> Enum.flat_map(fn {line, i} ->
                cond do
                  i in consumed ->
                    []

                  is_nil(last_entry) and i == open ->
                    # 空 goods 块：直接填入
                    [line | new_lines]

                  not is_nil(last_entry) and i == last_entry ->
                    # 原末项后还有新条目 -> 补上分隔逗号，逗号交给新末项收尾
                    sep = if String.ends_with?(line, ","), do: line, else: line <> ","
                    [sep | new_lines]

                  true ->
                    [line]
                end
              end)

            {out, length(add), if(add == [], do: :noop, else: :merged)}
        end

      stats = %{
        base
        | same: same_n,
          cross: cross_n,
          kept: length(kept_paths),
          added: added_now,
          created: action == :created,
          merged: action == :merged
      }

      {out, stats, kept_paths}
    end
  end

  # 计划范围 = mud/d 转换的 71 个区。以下区不在范围内（见
# docs/data-world-converted-ucl-comments.zh-CN.md 的范围判定）：
#   test        - 旧 Elixir 转换器的测试夹具（来源 test_minimal_world_v2_modified）
#   global      - 转换器测试语料区，含 987 条未转换标记，不接正式世界
#   liuxi / kissa-jarvi / lepakko-luola / sammatti / signature - 手工区，非转换产物
@excluded_zones ~w(test global liuxi kissa-jarvi lepakko-luola sammatti signature)

def run(apply?) do
    world_dir = Path.join(File.cwd!(), "data/world")
    zone_items = index_zone_items(world_dir)
    IO.puts("indexed #{map_size(zone_items)} zones")

    totals = %{same: 0, cross: 0, kept: 0, added: 0, npcs: 0, created: 0, merged: 0, files: 0, skipped: 0}
    kept_by_zone = %{}

    files =
      world_dir
      |> File.ls!()
      |> Enum.filter(fn file ->
        String.ends_with?(file, ".ucl") and
          not (Path.rootname(file) in @excluded_zones)
      end)
      |> Enum.sort()

    {totals, kept_by_zone} =
      Enum.reduce(files, {totals, kept_by_zone}, fn file, {totals, kept_by_zone} ->
        path = Path.join(world_dir, file)
        zone = Path.rootname(file)
        lines = File.read!(path) |> String.split("\n")
        blocks = npc_blocks(lines)

        rebuilt =
          Enum.map(blocks, fn {start, close, _name} ->
            b_start = start - 1
            b_end = (close || length(lines)) - 1
            block_lines = sl(lines, b_start, b_end)
            {new_block, stats, kept} = rebuild_block(block_lines, zone, zone_items)
            {b_start, (b_end - b_start + 1), new_block, stats, kept}
          end)

        if System.get_env("VENDOR_DEBUG_ZONE") == zone do
          IO.puts("  [debug #{zone}] lines=#{length(lines)} blocks=#{length(blocks)}")

          changed = Enum.filter(rebuilt, fn {_s, _l, _b, st, _k} -> st.added > 0 end)

          show =
            case System.get_env("VENDOR_DEBUG_KIND") do
              "merged" -> Enum.filter(changed, fn {_s, _l, _b, st, _k} -> st.merged end)
              "created" -> Enum.filter(changed, fn {_s, _l, _b, st, _k} -> st.created end)
              _ -> changed
            end

          IO.puts("  [debug #{zone}] 改动块数=#{length(changed)} 展示=#{length(show)}")

          show
          |> Enum.take(1)
          |> Enum.each(fn {b_start, orig_len, nb, st, _k} ->
            IO.puts(
              "    b_start=#{b_start} orig_len=#{orig_len} new_len=#{length(nb)} stats=#{inspect(st)}"
            )

            Enum.with_index(nb, b_start + 1)
            |> Enum.each(fn {l, i} -> IO.puts("      #{i}|#{l}") end)
          end)
        end

        out =
          rebuilt
          |> Enum.reverse()
          |> Enum.reduce(lines, fn {b_start, orig_len, new_block, _s, _k}, acc ->
            Enum.slice(acc, 0, b_start) ++ new_block ++ sl(acc, b_start + orig_len, -1)
          end)

        totals =
          Enum.reduce(rebuilt, totals, fn {_s, _l, _b, stats, _k}, acc ->
            %{
              acc
              | same: acc.same + stats.same,
                cross: acc.cross + stats.cross,
                kept: acc.kept + stats.kept,
                added: acc.added + stats.added,
                npcs: acc.npcs + 1,
                created: acc.created + if(stats.created, do: 1, else: 0),
                merged: acc.merged + if(stats.merged, do: 1, else: 0)
            }
          end)

        kept_paths = rebuilt |> Enum.flat_map(fn {_s, _l, _b, _st, k} -> k end) |> Enum.uniq()
        kept_by_zone = Map.put(kept_by_zone, zone, kept_paths)

        zone_stats =
          Enum.reduce(rebuilt, %{npcs: 0, kept: 0, same: 0, cross: 0, added: 0}, fn {_s, _l, _b, st, _k},
                                                                                          acc ->
            %{
              npcs: acc.npcs + 1,
              kept: acc.kept + st.kept,
              same: acc.same + st.same,
              cross: acc.cross + st.cross,
              added: acc.added + st.added
            }
          end)

        if zone_stats.kept > 0 or zone_stats.same > 0 or zone_stats.cross > 0 do
          IO.puts(
            "  #{zone}: npcs=#{zone_stats.npcs} same=#{zone_stats.same} cross=#{zone_stats.cross} kept=#{zone_stats.kept} added=#{zone_stats.added}"
          )
        end

        out = if out == lines, do: nil, else: out

        # 写入前用真实解析器校验，避免把写坏的语法落盘
        bad =
          case out do
            nil ->
              nil

            content ->
              text = Enum.join(content, "\n")

              try do
                Elias.parse(text)
                nil
              rescue
                e -> Exception.message(e)
              end
          end

        totals =
          cond do
            is_nil(out) ->
              totals

            not is_nil(bad) ->
              IO.puts("[SKIP] #{file} 解析失败，保持原样：#{bad}")
              %{totals | skipped: totals.skipped + 1}

            true ->
              if apply? do
                File.write!(path, Enum.join(out, "\n"))
              else
                IO.puts("[dry] #{file}")
              end

              %{totals | files: totals.files + 1}
          end

        {totals, kept_by_zone}
      end)

    IO.puts("\n=== 汇总 ===")
    IO.inspect(totals)

    IO.puts("\n仍保留注释的区（未解析目标）：")

    Enum.sort(kept_by_zone)
    |> Enum.each(fn {zone, paths} ->
      if paths != [], do: IO.puts("  #{zone}: #{length(paths)}")
    end)

    if apply?, do: IO.puts("\n已写入。"), else: IO.puts("\n(dry-run，未写入；加 --apply 生效)")
  end
end

# 必须显式 VENDOR_GO=1 才会执行（避免被 require 时误跑）
# 加 VENDOR_APPLY=1 才真正写盘
if System.get_env("VENDOR_GO") == "1" do
  VendorGoodsMigration.run(System.get_env("VENDOR_APPLY") == "1")
end
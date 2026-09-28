# 区域转换标准化流程（标准操作规程 SOP）

> 目的：将 `mud/d/<zone>` 的 LPC 源码标准化转换为可加载的 UTF-8 UCL，避免手工修补 UCL 导致的不可复现问题。
> 原则：**只改脚本，不改生成产物**。发现错误 → 定位脚本/参数 → 修复脚本 → 重跑。

---

## 标准化流程（5 步闭环）

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. RUN CONVERTER          │  mix kantele.convert_lpc --recursive    │
│      (LPC → UCL)          │  输出：<zone>.ucl + <zone>_comments.txt │
├─────────────────────────────────────────────────────────────────────┤
│ 2. VALIDATE OUTPUT        │  编码/语法/结构完整性自检               │
│      (编码/语法/结构)     │  必须全绿才能进下一步                   │
├─────────────────────────────────────────────────────────────────────┤
│ 3. RUN COORDINATES        │  assign_room_coords.exs                 │
│      (赋坐标)             │  输出：<zone>_coords.ucl                │
├─────────────────────────────────────────────────────────────────────┤
│ 4. VALIDATE COORDS        │  坐标完整性/UTF-8/语法再检              │
│      (坐标/编码/语法)     │  必须全绿才能进下一步                   │
├─────────────────────────────────────────────────────────────────────┤
│ 5. LOAD & SMOKE TEST      │  热更加载 + 自动冒烟测试 + 人工巡游      │
│      (热更/冒烟/人工)     │  通过 → 下一区域；失败 → 回步骤 1/3    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 详细步骤清单（每个区域必跑）

### Step 1 — 运行转换器
```bash
# 容器内
docker exec -w /app wuxia_mud_dev-app-1 \
  mix kantele.convert_lpc /mud/d/<zone> --recursive --zone <zone> --output /app/data/world

# 产出：
#   data/world/<zone>.ucl
#   data/world/<zone>_comments.txt
```

### Step 2 — 产出校验（自动化脚本 `validate_ucl.exs`）
```bash
docker exec wuxia_mud_dev-app-1 elixir /app/scripts/validate_ucl.exs data/world/<zone>.ucl
```
**校验项**：
| 类别 | 检查点 | 失败即阻断 |
|------|--------|------------|
| 编码 | `file` 报 UTF-8，无 BOM，无 CRLF | ✅ |
| 语法 | `Elias.parse` 无异常 | ✅ |
| 结构 | 含 `zones "<zone>"`、所有 `rooms "..."` 有匹配 `room_exits` | ✅ |
| 完整性 | 所有 `rooms` 有 `x/y/z`（可为 0）、`room_exits` 目标要么本区 `rooms.xxx.id` 要么外部绝对路径 | ✅ |
| 字符 | 无孤立 `}`、无多余 `,`、字符串无未闭合 | ✅ |

> **失败处理**：定位是转换器 bug（如字符串未转义、括号不匹配） → 修 `lpc_converter.ex` → **重跑 Step 1**，不得手改 `.ucl`。

### Step 3 — 运行坐标脚本
```bash
docker exec wuxia_mud_dev-app-1 elixir /app/scripts/assign_room_coords.exs \
  data/world/<zone>.ucl <center_room> --output data/world/<zone>_coords.ucl
```
- `<center_room>` 取自 `docs/mud-d-zone-center-connections.zh-CN.md`
- 产出：`data/world/<zone>_coords.ucl`

### Step 4 — 坐标产出校验（复用 `validate_ucl.exs` + 额外检查）
```bash
docker exec wuxia_mud_dev-app-1 elixir /app/scripts/validate_ucl.exs data/world/<zone>_coords.ucl
```
**额外检查**：
- 所有 `rooms` 有非零坐标（或显式 `(0,0,0)` 仅限中心房）
- 坐标无冲突（同坐标不超过 1 个房间）
- 中心房坐标为 `(0,0,0)`
- BFS 连通：从中心房可达所有本区房间

> **失败处理**：定位 `assign_room_coords.exs` bug（方向向量、BFS 队列、孤儿房堆叠） → 修脚本 → **重跑 Step 3**，不得手改坐标。

### Step 5 — 热更加载 + 冒烟测试
```bash
# 5.1 替换生产文件
docker cp data/world/<zone>_coords.ucl wuxia_mud_dev-app-1:/app/data/world/<zone>.ucl

# 5.2 热更（不重启容器）
docker exec wuxia_mud_dev-app-1 iex --remsh app@<host> -e 'World.reload_zone("<zone>")'

# 5.3 自动化冒烟
docker exec wuxia_mud_dev-app-1 mix test test/zone_<zone>_test.exs

# 5.4 人工巡游（巫师号）
#   goto <zone>/<center> → walk 全图 → 检查 exits/描述/NPC/物品/任务
#   记录：test_logs/<zone>_wizard_<date>.md

# 5.5 玩家验收（可选）
#   从 city 走官道进区 → 完成主线/战斗/技能 → 传送回城
#   记录：test_logs/<zone>_player_<date>.md
```

---

## 自动化校验脚本 `validate_ucl.exs`（新建）

```elixir
# scripts/validate_ucl.exs
# 用法：elixir scripts/validate_ucl.exs <file.ucl>

defmodule ValidateUCL do
  def main([path]) do
    content = File.read!(path)
    checks = [
      check_encoding(content),
      check_syntax(content),
      check_structure(content),
      check_integrity(content),
      check_chars(content)
    ]
    
    failed = Enum.filter(checks, &match?({:fail, _}, &1))
    if failed == [] do
      IO.puts("✅ All checks passed: #{path}")
      System.halt(0)
    else
      Enum.each(failed, fn {:fail, msg} -> IO.puts("❌ #{msg}") end)
      System.halt(1)
    end
  end

  defp check_encoding(content) do
    if String.valid?(content) && !String.starts_with?(content, <<0xFF, 0xFE>>) &&
       !String.contains?(content, "\r") do
      {:ok, "UTF-8, no BOM, no CRLF"}
    else
      {:fail, "Encoding: must be UTF-8, no BOM, LF only"}
    end
  end

  defp check_syntax(content) do
    case Elias.parse(content) do
      {:ok, _} -> {:ok, "Elias.parse OK"}
      {:error, err} -> {:fail, "Syntax: #{inspect(err)}"}
    end
  end

  defp check_structure(content) do
    # 简单结构检查：有 zone 头、rooms 块、room_exits 块
    has_zone = String.match?(content, ~r/zones\s+"\w+"/)
    has_rooms = String.match?(content, ~r/rooms\s+"\w+"/)
    has_exits = String.match?(content, ~r/room_exits\s+"\w+"/)
    if has_zone && has_rooms && has_exits do
      {:ok, "Structure: zone/rooms/exists present"}
    else
      {:fail, "Structure: missing zone/rooms/exits"}
    end
  end

  defp check_integrity(content) do
    # 统计 rooms 与 room_exits 数量匹配
    rooms = Regex.scan(~r/rooms\s+"(\w+)"/, content, capture: :first) |> Enum.count()
    exits = Regex.scan(~r/room_exits\s+"(\w+)"/, content, capture: :first) |> Enum.count()
    if rooms == exits && rooms > 0 do
      {:ok, "Integrity: #{rooms} rooms, #{exits} exits match"}
    else
      {:fail, "Integrity: rooms(#{rooms}) != exits(#{exits})"}
    end
  end

  defp check_chars(content) do
    # 无孤立 }、无多余逗号、字符串闭合
    issues = []
    if String.match?(content, ~r/^\s*}\s*}/m) do
      issues = ["孤立双闭合括号 } }"]
    end
    if String.match?(content, ~r/,\s*}/m) do
      issues = issues ++ ["闭合括号前多余逗号 , }"]
    end
    # 简单字符串闭合检查：引号成对
    quote_count = String.graphemes(content) |> Enum.count(&(&1 == "\""))
    if rem(quote_count, 2) != 0 do
      issues = issues ++ ["引号不成对"]
    end
    if issues == [] do
      {:ok, "Chars: no stray braces/commas, quotes balanced"}
    else
      {:fail, "Chars: #{Enum.join(issues, "; ")}"}
    end
  end
end

ValidateUCL.main(System.argv())
```

---

## 容器内一键跑单区域（示例：baituo）

```bash
# 1. 转换
docker exec -w /app wuxia_mud_dev-app-1 \
  mix kantele.convert_lpc /mud/d/baituo --recursive --zone baituo --output /app/data/world

# 2. 校验转换产出
docker exec wuxia_mud_dev-app-1 elixir /app/scripts/validate_ucl.exs /app/data/world/baituo.ucl

# 3. 赋坐标
docker exec wuxia_mud_dev-app-1 elixir /app/scripts/assign_room_coords.exs \
  /app/data/world/baituo.ucl guangchang --output /app/data/world/baituo_coords.ucl

# 4. 校验坐标产出
docker exec wuxia_mud_dev-app-1 elixir /app/scripts/validate_ucl.exs /app/data/world/baituo_coords.ucl

# 5. 热更 + 冒烟
docker cp data/world/baituo_coords.ucl wuxia_mud_dev-app-1:/app/data/world/baituo.ucl
docker exec wuxia_mud_dev-app-1 iex --remsh app@<host> -e 'World.reload_zone("baituo")'
docker exec wuxia_mud_dev-app-1 mix test test/zone_baituo_test.exs
```

---

## 错误分类与定位表

| 现象 | 可能原因 | 定位脚本 |
|------|----------|----------|
| `Elias.parse` 报错 `","` | 字符串含未转义引号/逗号、或多余逗号 | `lpc_converter.ex` 的 `generate_room_ucl` / `generate_*_ucl` |
| UTF-16 / BOM / CRLF | `File.write!` 未强制 UTF-8 | `kantele.convert_lpc.ex` 的 `File.write!` |
| `room_exits` 缺闭合 `}` | 生成时 `}` 与上行合并 | `generate_room_ucl` / `build_exits_block` |
| 坐标冲突/全 0 | BFS 队列/方向向量/孤儿房逻辑 | `assign_room_coords.exs` 的 `drain` / `visit_neighbour` / `orphans` |
| 跨区出口指向不存在房间 | 转换器未解析外部路径、或目标区未转 | `lpc_converter.ex` 的 `extract_exit_*`、跨区依赖顺序 |

---

## 文档维护
- 本文档位于 `docs/zone-conversion-sop.zh-CN.md`
- 每完成一个区域，在 `docs/zone-conversion-checklist.zh-CN.md` 打勾并记录：区域、日期、关键修复 commit
- 发现新错误模式 → 追加到「错误分类与定位表」 → 修对应脚本 → 回滚重跑
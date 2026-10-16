# F4 迁移备忘：LPC 权威源字节损坏（U+FFFD）

> 记录 performs 译文验收中，因权威源 `C:\files\git\mud\...\*.c` 字节损坏导致的 1 例 FAIL。
> 结论：**不改 `.c`（只读权威源）**、**不改 `scripts/perf_acceptance.py`（禁止放水）**；
> 受影响的 perform 已登记保护并在此备案。

## 1. 现象

对 `lib/kantele/combat/skills/performs` 全量 728 个 `.ex` 执行验收：

- **727 PASS / 1 FAIL**
- FAIL：`beiming_shengong/suck.ex`
- MISSING 文案：`你的北冥神功功力不够，不能吸取对方的丹元！<U+FFFD>n`

## 2. 根因

LPC 源字符串转义 `\n` 的**反斜杠字节（0x5C）被替换为 UTF-8 替换字符 U+FFFD（EF BF BD）**，
于是 `\n` 变成 `<U+FFFD>n`。该损坏已在 `C:\files\git\mud` 的 HEAD 提交中，
与本地 checkout 无关（worktree == HEAD）。

扫描 `kungfu/skill/**/*.c` 命中 3 处：

| 文件 | 行 | 损坏片段（U+FFFD 记作 `<U+FFFD>`） | 期望 |
|------|----|--------------------------------------|------|
| `beiming-shengong/suck.c` | 37 | `...丹元！<U+FFFD>n"` | `...丹元！\n"` |
| `feixing-shu.c` | 13 | `...？<U+FFFD>n"` | `...？\n"` |
| `five-avoid.c` | 19 | `...消散！<U+FFFD>` | `...消散！\n` |

其中**只有 `suck.c` 属于某个 perform 的权威源**。另外两个文件位于 `kungfu/skill/` 顶层，
不在任何 skill 子目录内，`perf_acceptance.build_c_map()` 只遍历子目录，故不映射到任何 `.ex`。

## 3. Elixir 侧状态（正确）

`lib/kantele/combat/skills/performs/beiming_shengong/suck.ex:118` 已是正确文案：

```elixir
{:error, conn, "你的北冥神功功力不够，不能吸取对方的丹元！\n"}
```

即 **`.ex` 正确、`.c` 损坏**。验收工具按字面比对，因此对 `suck.ex` 报 FAIL（属预期）。

## 4. 处理决定（2026-10-15）

- **豁免（白名单）**：`beiming_shengong/suck.ex` 已列入 `scripts/protected_performs.txt`（第 24 行），
  即验收流程既有的保护登记表；`python scripts/perf_acceptance.py --all-pending` 全量扫描会跳过它。
- **不改 `.c`**：`C:\files\git\mud` 为只读权威源（见 `docs/F4-migration-plan-E.zh-CN.md` 第 44 行）。
- **不改工具**：`scripts/perf_acceptance.py` 禁止修改（同上，第 21 / 44 行）。
- **不引入 U+FFFD 到 `.ex`**：避免把损坏字符带进译文。

## 5. 复现与核对

```bash
# 单文件：预期 FAIL，MISSING 含 <U+FFFD>
python scripts/perf_acceptance.py beiming_shengong/suck.ex

# 全量（跳过保护文件）：预期 0 FAIL
python scripts/perf_acceptance.py --all-pending
```

> 注意：工具只在 `--all-pending` 模式下读取保护表；显式传入路径或 `--json` 全量列表时**不会**应用豁免，
> 因此这两类调用仍会把 `suck.ex` 记为 1 FAIL —— 此为该损坏的**已知、已备案例外**，非译文缺陷。

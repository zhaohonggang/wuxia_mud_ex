#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 docs/F4-protected-review.zh-CN.md：受保护 perform 的严格判据复核计划。

用法（仓库根目录）：
    python scripts/gen_protected_review.py

判据与 scripts/perf_acceptance.py 完全一致（MISSING 为空才 PASS），
不修改被复核文件，仅产出报告。
"""
from __future__ import annotations

import datetime
from collections import Counter
from pathlib import Path

import perf_acceptance as pa

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "F4-protected-review.zh-CN.md"
EXC = ROOT / "scripts" / "f4_exceptions.tsv"


def main() -> int:
    prot = sorted(pa.load_protected())
    cmap = pa.build_c_map()

    passed: list[str] = []
    failed: list[tuple[str, int, str]] = []
    missing_total = 0

    for rel in prot:
        r = pa.check_one(rel, cmap)
        if r["status"] == "PASS":
            passed.append(rel)
            continue
        miss = len(r["missing"])
        missing_total += miss
        c_path = cmap.get(rel)
        lpc = "—"
        if c_path is not None:
            _, p = c_path
            try:
                lpc = p.relative_to(ROOT.parent / "mud").as_posix()
            except ValueError:
                lpc = p.as_posix()
        failed.append((rel, miss, lpc))

    failed.sort(key=lambda x: x[0])
    today = datetime.date.today().isoformat()

    lines: list[str] = []
    lines.append("# F4 迁移计划 — 受保护文件复核（P0 · 严格判据）")
    lines.append("")
    lines.append(f"> 生成时间：{today}　|　工具：`scripts/perf_acceptance.py`")
    lines.append("")
    lines.append("## 背景")
    lines.append("")
    lines.append(f"`scripts/protected_performs.txt` 当前共 **{len(prot)}** 条受保护 perform。")
    lines.append(
        "用**严格判据**（`.ex` 代码内中文文案 vs `.c` 代码内中文文案，"
        "**逐条字面一致，不做模糊等价**）复核："
    )
    lines.append("")
    lines.append(
        f"- **PASS = {len(passed)}**，**FAIL = {len(failed)}**，"
        f"MISSING 合计 **{missing_total}** 条。"
    )
    lines.append(
        "- 判据 = `check_one`：`Counter(norm(src)) - Counter(norm(tgt))` 为空才 PASS"
        "（MISSING 必须为空；EXTRA 不判错）。"
    )
    lines.append("- 本计划**独立于 A/B 号计划**，可并行执行；A/B 只处理非受保护文件。")
    lines.append("")
    lines.append("## 已 PASS（无需处理）")
    lines.append("")
    for rel in passed:
        lines.append(f"- `{rel}`")
    lines.append("")
    lines.append("## 待复核 / 待修订")
    lines.append("")
    lines.append("| # | 文件 | MISSING | 对应 LPC 源 |")
    lines.append("|---:|---|---:|---|")
    for i, (rel, miss, lpc) in enumerate(failed, 1):
        lines.append(f"| {i} | `{rel}` | {miss} | `{lpc}` |")
    lines.append("")
    lines.append("## 处理流程（每个文件）")
    lines.append("")
    lines.append("1. 读对应 `.c`（上表末列；注意 `perform/`、`exert/`、`-`/`'` 变体）。")
    lines.append("2. **逐条字面一致**修正 `.ex`：")
    lines.append(
        "   - 措辞差异（`难以施展`↔`无法施展`、`修为不够`↔`不够娴熟`、"
        "`真气不够`↔`真气不足`）**改成与 `.c` 完全一致**；"
    )
    lines.append(
        "   - 名字插在字符串中间而被 `.c` 拆成多段时，`.ex` **必须同样拆段**："
        "`\"…手中\" <> weapon_name <> \"，发出…\"`；"
    )
    lines.append("   - 中文弯引号 `“”‘’` 与直引号按 `.c` 原样保留。")
    lines.append("3. `python scripts/perf_acceptance.py <rel>` 须 PASS。")
    lines.append('4. `docker exec wuxia_mud_dev-app-1 sh -c "cd /app && mix compile"` 须 EXIT=0。')
    lines.append("5. 文件本就在 `protected_performs.txt` 中，无需追加。")
    lines.append("")
    lines.append("## 例外登记（判定为工具误报 / 无需修改）")
    lines.append("")
    lines.append("| 文件 | 理由 | 处理 |")
    lines.append("|---|---|---|")
    for row in load_exceptions():
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT} : PASS={len(passed)} FAIL={len(failed)} MISSING={missing_total}")
    return 0


def load_exceptions():
    """读取 scripts/f4_exceptions.tsv（三列 TSV，无表头，# 开头为注释）。"""
    if not EXC.exists():
        return [("（待填）", "", "")]
    rows = []
    # utf-8-sig：容忍编辑器写入的 BOM
    for line in EXC.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cols = [c.strip() for c in line.split("\t")]
        while len(cols) < 3:
            cols.append("")
        rows.append(tuple(cols[:3]))
    return rows or [("（待填）", "", "")]


if __name__ == "__main__":
    raise SystemExit(main())

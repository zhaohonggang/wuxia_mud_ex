#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4p backfill: 给 16 个城门/关卡房间回填 look_gaoshi 的 item_desc 配置。

对应 LPC：
    string look_gaoshi() { return FINGER_D->get_killer() + "\n<本城知府/提督落款>"; }

本端口由新 handler `finger_d_killer` 渲染：读 `FingerD.get_killer_text()`（FINGER_D
子系统，见 lib/kantele/world/finger_d.ex）再拼接 UCL 里的 footer 落款。footer 完整
包含 LPC 里那个前导 "\n"，所以这里直接把整段落款写进配置即可。

目标房间（zone_file, stem, footer），footer 来自各城门 LPC 的 return 字面量：
（raw string 保持 \\n 为字面两字符）

    chengdu  (east/north/south/west)gate : "\\n成都提督\\n吴天德\\n"
    city     (bei/dong/nan/xi)men        : "\\n扬州知府\\n程药发\\n"
    lanzhou  (bei/dong/nan/xi)men        : "\\n         兰州知府\\n                     耶律巡\\n"
    suzhou   (bei/dong/nan/xi)men        : "\\n苏州知府\\n冯正东\\n"

门禁（与 P5-4n/o 一致）：G1 dry-run 统计 -> G2 备份 -> G3 写盘 -> G4 validate_ucl 全绿
-> G5 幂等复跑 0 待改。写入用 newline="" 以避开 Windows CRLF（validate_ucl 的 CR 检查会拒绝）。

用法：
    python scripts/backfill_finger_d_gaoshi.py            # dry-run
    python scripts/backfill_finger_d_gaoshi.py --apply    # 真正写盘
"""
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_WORLD = os.path.join(ROOT, "data", "world")
VALIDATE = os.path.join(ROOT, "scripts", "validate_ucl.py")

# (zone_file, stem, footer)
TARGETS = [
    # chengdu
    ("chengdu.ucl", "eastgate", r"\n成都提督\n吴天德\n"),
    ("chengdu.ucl", "northgate", r"\n成都提督\n吴天德\n"),
    ("chengdu.ucl", "southgate", r"\n成都提督\n吴天德\n"),
    ("chengdu.ucl", "westgate", r"\n成都提督\n吴天德\n"),
    # city
    ("city.ucl", "beimen", r"\n扬州知府\n程药发\n"),
    ("city.ucl", "dongmen", r"\n扬州知府\n程药发\n"),
    ("city.ucl", "nanmen", r"\n扬州知府\n程药发\n"),
    ("city.ucl", "ximen", r"\n扬州知府\n程药发\n"),
    # lanzhou（注意前导空格是 LPC 原样，保留）
    ("lanzhou.ucl", "beimen", r"\n         兰州知府\n                     耶律巡\n"),
    ("lanzhou.ucl", "dongmen", r"\n         兰州知府\n                     耶律巡\n"),
    ("lanzhou.ucl", "nanmen", r"\n         兰州知府\n                     耶律巡\n"),
    ("lanzhou.ucl", "ximen", r"\n         兰州知府\n                     耶律巡\n"),
    # suzhou
    ("suzhou.ucl", "beimen", r"\n苏州知府\n冯正东\n"),
    ("suzhou.ucl", "dongmen", r"\n苏州知府\n冯正东\n"),
    ("suzhou.ucl", "nanmen", r"\n苏州知府\n冯正东\n"),
    ("suzhou.ucl", "ximen", r"\n苏州知府\n冯正东\n"),
]

KIND = "finger_d_killer"

OPEN_RE = lambda stem: re.compile(r'^(\s*)rooms\s+"%s"\s*\{' % re.escape(stem))


def find_rooms_block_close(text, stem):
    """返回 `rooms "<stem>" { ... }` 块的闭括号行号（0-based），找不到返回 None。

    用括号深度扫描：从 `rooms "stem" {` 那行起，逐行累计 '{' 与 '}' 数量，
    深度回到 0 的那一行即为该 rooms 块的结束 '}'。块内若有嵌套（actions/item_desc）
    也能正确跳过。
    """
    lines = text.split("\n")
    start = None
    for i, line in enumerate(lines):
        if OPEN_RE(stem).match(line):
            start = i
            break
    if start is None:
        return None
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count("{")
        depth -= lines[j].count("}")
        if depth == 0 and j > start:
            return j
    return None


def already_done(text, stem):
    close = find_rooms_block_close(text, stem)
    if close is None:
        return False
    lines = text.split("\n")
    seg = "\n".join(lines[: close + 1])
    return ('kind = "%s"' % KIND) in seg


def build_insert(footer):
    return (
        '      item_desc = {\n'
        '    gaoshi = {\n'
        '      kind = "%s"\n' % KIND +
        '      footer = "%s"\n' % footer +
        '    }\n'
        '  }\n'
    )


def plan_insertions():
    plan = []
    for zone, stem, footer in TARGETS:
        path = os.path.join(DATA_WORLD, zone)
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        close = find_rooms_block_close(text, stem)
        if close is None:
            print("  [SKIP] %s :: %s 找不到 rooms 块" % (zone, stem), file=sys.stderr)
            continue
        if already_done(text, stem):
            print("  [IDEMPOTENT] %s :: %s 已有 finger_d_killer，跳过" % (zone, stem))
            continue
        plan.append((zone, stem, footer, close))
    return plan


def backup(plan):
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(ROOT, "tmp", "backup-fingerd-%s" % ts)
    affected = sorted({z for z, _, _, _ in plan})
    os.makedirs(bdir, exist_ok=True)
    for z in affected:
        shutil.copy2(os.path.join(DATA_WORLD, z), os.path.join(bdir, z))
    print("  备份 %d 个文件 -> %s" % (len(affected), bdir))
    return bdir


def apply_plan(plan):
    by_file = {}
    for zone, stem, footer, close in plan:
        by_file.setdefault(zone, []).append((stem, footer, close))
    for zone, items in by_file.items():
        path = os.path.join(DATA_WORLD, zone)
        with open(path, "r", encoding="utf-8") as f:
            lines = f.read().split("\n")
        # 从后往前插，避免行号偏移
        for stem, footer, close in sorted(items, key=lambda x: x[2], reverse=True):
            lines.insert(close, build_insert(footer).rstrip("\n"))
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write("\n".join(lines))
        print("  写入 %s (+%d 处 item_desc.gaoshi)" % (zone, len(items)))


def validate():
    ok = True
    affected = sorted({z for z, _, _ in TARGETS})
    for z in affected:
        path = os.path.join(DATA_WORLD, z)
        try:
            res = subprocess.run([sys.executable, VALIDATE, path],
                                 capture_output=True, text=True, cwd=ROOT)
            if res.returncode != 0:
                ok = False
                print("  [VALIDATE FAIL] %s\n%s" % (z, res.stdout[-2000:]))
            else:
                print("  [validate ok] %s" % z)
        except Exception as e:  # noqa
            ok = False
            print("  [VALIDATE ERROR] %s: %s" % (z, e))
    return ok


def main():
    apply = "--apply" in sys.argv
    print("== P5-4p finger_d_gaoshi backfill ==")
    print("模式: %s" % ("APPLY" if apply else "dry-run"))
    plan = plan_insertions()
    print("计划插入 %d 处：" % len(plan))
    for zone, stem, footer, _ in plan:
        print("  + %s :: %s  (footer=%r)" % (zone, stem, footer))

    if not apply:
        print("\n(dry-run 结束；加 --apply 真正写盘)")
        return

    backup(plan)
    apply_plan(plan)
    print("\n== 校验 ==")
    if not validate():
        print("VALIDATE 失败，请检查。", file=sys.stderr)
        sys.exit(1)
    print("\n== 幂等复跑 ==")
    plan2 = plan_insertions()
    print("复跑待改：%d 处（应为 0）" % len(plan2))
    if plan2:
        for zone, stem, footer, _ in plan2:
            print("  仍未处理：%s :: %s" % (zone, stem))
        sys.exit(2)
    print("OK：全部回填完毕且幂等。")


if __name__ == "__main__":
    main()

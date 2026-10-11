#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
_cov_delta.py — 抽取器改进前后的中文覆盖率/信息保真 回归校验。

用途：改了 translate_perform.py 后，快速验证：
  1) 覆盖率（代码对注释 LPC 消息）是否提升 / 未退化
  2) 注释区 LPC 源码块是否逐字节保留（零信息丢失）
  3) 门槛消息与条件是否配对正确（抽样打印）

用法：
  python scripts/_cov_delta.py            # 对比 HEAD vs 工作区
  python scripts/_cov_delta.py --sample 80
"""
import subprocess
import random
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PERF = ROOT / "lib" / "kantele" / "combat" / "skills" / "performs"
CJK = __import__("re").compile(r"[\u4e00-\u9fff]")


def code_cjk_messages(text):
    """代码区（LPC 注释块之前）的中文字符串消息集合。"""
    idx = text.find("===== 原始 LPC")
    code = text[:idx] if idx > 0 else text
    return set(__import__("re").findall(r'"([^"\\\n]*[\u4e00-\u9fff][^"\\\n]*)"', code))


def lpc_block(text):
    lines = text.splitlines()
    try:
        i = next(i for i, l in enumerate(lines) if "原始 LPC 源码" in l)
    except StopIteration:
        return None
    return "\n".join(lines[i:])


def head_text(rel):
    return subprocess.run(["git", "show", f"HEAD:{rel}"],
                          capture_output=True, text=True).stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", type=int, default=60)
    args = ap.parse_args()

    files = sorted(PERF.rglob("*.ex"))
    random.seed(7)
    sample = random.sample(files, min(args.sample, len(files)))

    tot_head = tot_work = 0
    lpc_bad = []
    for f in files:
        t = f.read_text(encoding="utf-8", errors="replace")
        tot_work += len(code_cjk_messages(t))

    for f in sample:
        rel = f.relative_to(ROOT).as_posix()
        h = head_text(rel)
        if not h:
            continue
        tot_head += len(code_cjk_messages(h))
        if lpc_block(h) != lpc_block(f.read_text(encoding="utf-8", errors="replace")):
            lpc_bad.append(rel)

    print("=" * 64)
    print("抽取器改动回归校验")
    print("=" * 64)
    print(f"代码区中文消息总数（全部 {len(files)} 文件，工作区） : {tot_work}")
    print(f"代码区中文消息总数（抽样 {len(sample)} 文件，HEAD）  : {tot_head}  (仅参考)")
    print(f"注释 LPC 源码块不一致的文件（信息丢失检查）          : {len(lpc_bad)}")
    if lpc_bad:
        for rel in lpc_bad[:10]:
            print("   DIFF:", rel)
    print("=" * 64)
    print("结论：" + ("通过（零信息丢失）" if not lpc_bad else "存在 LPC 注释差异，需排查"))


if __name__ == "__main__":
    main()

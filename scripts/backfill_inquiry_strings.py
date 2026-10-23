#!/usr/bin/env python3
r"""Backfill plain-string LPC inquiry entries into the Elixir UCL world data.

Scope: P5-4at 的第二批回填——只回填 **纯字符串** 问询（LPC `set("inquiry")`
里 `"key" : "text"` 形式的条目）。闭包条目（ask_skill*/give_item/quest）不在
本脚本范围，逐 NPC 人工移植（见 docs/lpc-port-gaps.zh-CN.md）。

数据来源：scripts/survey_inquiry_closures.py 产出的 tmp/inquiry_survey.json
（字符串条目已由 parse_c_string 还原转义）。

纪律（与既有回填一致）：
  1. 默认 dry-run，只打印将写入的条目；
  2. --apply 时才落盘，落盘前整文件备份到 tmp/backup-inq-strings-<TS>/；
  3. 写后必须过 scripts/validate_ucl.py；
  4. 幂等：已在 inquiries 块里的键跳过，重跑 = 0 pending。

UCL 字符串规则（validate_ucl.py / EliasStrings 强制）：
  - `"..."` 内只允许 `\"` / `\'` 与 `\`+词（`\n`/`\t`）；**`\\` 是语法错误**；
  - 真换行是语法错误 → 必须先转成 `\n` 两字符；
  - `[` `]` `;` 在字符串内非法 → 出现即报错中止。
"""
import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EX = ROOT / "data" / "world"
SURVEY = ROOT / "tmp" / "inquiry_survey.json"

UCL_CHAR = re.compile(r'characters\s+"([^"]+)"\s*\{')
INQ_START = re.compile(r'^([ \t]*)inquiries\s*=\s*([\[{])', re.M)


def brace_block(src, start):
    """src[start] 必须是 '{' 或 '['；返回配平后的整块文本（含两端符号）。

    必须跳过 `#` 注释与 `"..."` 字符串：数据文件里有注释含花括号的例子
    （如 `# LPC set("long") { ... }`），裸数花括号会把块边界算到下一个角色去
    （xiakedao.ucl 的 shipotian 就踩过，插入点跑飞到 carry 数组里）。
    """
    open_ch = src[start]
    close_ch = "}" if open_ch == "{" else "]"
    depth, j, n = 0, start, len(src)
    while j < n:
        c = src[j]
        if c == "#":
            k = src.find("\n", j)
            j = n if k == -1 else k
            continue
        if c == '"':
            j += 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == '"':
                    break
                j += 1
            j += 1
            continue
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                break
        j += 1
    return src[start : j + 1]


def esc(text):
    """LPC 还原文本 → UCL 合法字符串字面量（不含外层引号）。"""
    t = text.strip()
    # LPC 源码里的 `\n` 已被 parse_c_string 还原成真换行，且常带源码缩进；
    # 这里压成单空格（丢的是 LPC 作者的排版缩进，不是内容）。
    t = " ".join(p.strip() for p in t.split("\n") if p.strip())
    for ch, why in (('"', "dquote"), ("\\", "backslash"), ("[", "lbracket"),
                    ("]", "rbracket"), (";", "semicolon")):
        if ch in t:
            raise SystemExit(f"UCL 字符串含非法字符 {why}: {t!r}")
    return t


def existing_keys(block_text):
    """已在 inquiries 块里的键（数组形 `{ key = "x" ... }` 与映射形 `x = ...` 都认）。"""
    keys = set()
    keys.update(re.findall(r'\bkey\s*=\s*"([^"]*)"', block_text))
    for m in re.finditer(r'^\s*([^\s={}"\#]+)\s*=\s*', block_text, re.M):
        keys.add(m.group(1))
    return keys


def patch_file(path, char_key, entries, note, src=None):
    """把 entries 写入 path 中 characters "<char_key>" 的 inquiries 块。

    src 为调用方持有的**内存中最新文本**（同一文件多个角色要串行修补，
    不能每次从磁盘重读，否则后一次覆盖前一次的结果）。
    返回 (改动数, 新文本)。无改动返回 (0, 原文)。
    """
    if src is None:
        src = path.read_bytes().decode("utf-8")
    # 定位角色块（记录开行缩进，供新建块时对齐收尾括号）
    char_span = None
    char_indent = "    "
    for m in UCL_CHAR.finditer(src):
        if m.group(1) != char_key:
            continue
        line_start = src.rfind("\n", 0, m.start()) + 1
        char_indent = src[line_start : m.start()]
        i = m.end() - 1
        blk = brace_block(src, i)
        char_span = (i, i + len(blk))
        break
    if char_span is None:
        raise SystemExit(f"{path.name}: 找不到 characters \"{char_key}\"")
    cs, ce = char_span
    body = src[cs:ce]

    im = INQ_START.search(body)
    if im:
        indent = im.group(1)
        form = im.group(2)
        # group(2) 就是开括号本身；brace_block 要从开括号起算，故回退一位
        bs = im.end(2) - 1
        blk = brace_block(body, bs)
        have = existing_keys(blk)
        todo = [(k, v) for k, v in entries if k not in have]
        if not todo:
            return 0, src
        if form == "{":
            # 映射形：在收尾 `}` 前插入 `    key = "text"`
            add = "".join(f'\n{indent}  {k} = "{esc(v)}"' for k, v in todo)
            new_blk = blk[:-1].rstrip() + add + f"\n{indent}}}"
        else:
            # 数组形：条目间逗号分隔、**无尾逗号**（elias 数组语法要求逗号后必须有值）。
            # 先把原块尾逗号去掉，再用 ",\n" 连接新条目，最后一条不带逗号。
            lines = [f'{indent}  {{ key = "{k}" value = "{esc(v)}" }}' for k, v in todo]
            new_blk = blk[:-1].rstrip().rstrip(",") + ",\n" + ",\n".join(lines) + f"\n{indent}]"
        new_body = body[:bs] + new_blk + body[bs + len(blk) :]
        return len(todo), src[:cs] + new_body + src[ce:]

    # 无 inquiries 块：在角色块收尾 `}` 前新建一个（数组形，与转换器产出一致）
    todo = entries
    lines = [f'{char_indent}  {{ key = "{k}" value = "{esc(v)}" }}' for k, v in todo]
    new_body = (
        body[:-1].rstrip()
        + "\n\n" + note + "\n"
        + f"{char_indent}inquiries = [\n" + ",\n".join(lines) + f"\n{char_indent}]\n"
        + char_indent + "}"
    )
    return len(todo), src[:cs] + new_body + src[ce:]


def main():
    apply = "--apply" in sys.argv
    data = json.loads(SURVEY.read_text(encoding="utf-8"))

    # LPC 文件 → (Elixir zone, character key, 备注注释)
    TARGETS = {
        "kungfu/class/huashan/feng-buping.c": ("huashan", "fengbuping",
            "      # LPC kungfu/class/huashan/feng-buping.c：剑宗传人封不平的问询（纯字符串条目）"),
        "kungfu/class/huashan/lao.c": ("huashan", "lao_denuo",
            "      # LPC kungfu/class/huashan/lao.c：劳德诺的问询（纯字符串条目）"),
        "kungfu/class/shenlong/zhang.c": ("shenlong", "zhangdanyue",
            "      # LPC kungfu/class/shenlong/zhang.c：张淡月的问询（纯字符串条目）"),
        "kungfu/class/wudu/qiyunao.c": ("wudu", "wudu_qiyunao",
            "      # LPC kungfu/class/wudu/qiyunao.c：齐云敖的毒经问询（纯字符串条目）"),
        "kungfu/class/xiakedao/shi.c": ("xiakedao", "shipotian",
            "      # LPC kungfu/class/xiakedao/shi.c：石破天的问询（纯字符串条目）"),
        "adm/npc/nanxian.c": ("signature", "nanxian",
            "      # LPC adm/npc/nanxian.c：南贤的问询（纯字符串条目）"),
        "d/wuguan/npc/guanjia6.c": ("wuguan", "guanjia6",
            "      # LPC d/wuguan/npc/guanjia6.c：武馆管家的问询（纯字符串条目）"),
        "d/xiangyang/npc/wuxiuwen.c": ("xiangyang", "wuxiuwen",
            "      # LPC d/xiangyang/npc/wuxiuwen.c：武修文的问询（纯字符串条目）"),
        "kungfu/class/miao/miao.c": ("zhongzhou", "miao",
            "      # LPC kungfu/class/miao/miao.c：苗人凤（中原苗家师父）的问询（纯字符串条目）"),
        "kungfu/class/taohua/huang.c": ("taohua", "huangyaoshi",
            "      # LPC kungfu/class/taohua/huang.c：黄药师的问询（纯字符串条目）"),
        "kungfu/class/shang/ming.c": ("shaolin", "shang_jianming",
            "      # LPC kungfu/class/shang/ming.c：商剑鸣的问询（纯字符串条目）"),
        "adm/npc/ganjiang.c": ("signature", "ganjiang",
            "      # LPC adm/npc/ganjiang.c：干将的问询（纯字符串条目）"),
        "adm/npc/moye.c": ("signature", "moye",
            "      # LPC adm/npc/moye.c：莫邪的问询（纯字符串条目）"),
    }

    # survey 解析器的盲区：字符串条目后紧跟 LPC 注释行时，STRING_ENTRY 的
    # lookahead（`\n\s*"` 或 `]`）失配，整条被漏掉。此处按 LPC 原文手工补齐。
    EXTRA = {
        "kungfu/class/taohua/huang.c": [
            ("无常丹", "…嗯…等你学通了桃花药理的奥妙，自己慢慢制吧。"),
        ],
    }

    total = 0
    # 内存里按文件累积：同一 UCL 的多个角色要串行打在同一个文本上
    mem = {}
    for f, (zone, key, note) in TARGETS.items():
        items = data.get(f, {})
        entries = [
            (k, v.get("text") or " ".join(v.get("texts") or []))
            for k, v in items.items()
            if v["class"] in ("string_value", "text_only") and (v.get("text") or v.get("texts"))
        ]
        entries += [(k, v) for k, v in EXTRA.get(f, []) if k not in dict(entries)]
        if not entries:
            continue
        path = EX / f"{zone}.ucl"
        n, new_src = patch_file(path, key, entries, note, mem.get(path))
        if n:
            total += n
            mem[path] = new_src
            print(f"  {zone}/{key}: +{n}  (from {f})")
        else:
            print(f"  {zone}/{key}: 0 (already complete)")
    touched = mem

    print(f"\nTOTAL: {total} entries pending")
    if not total:
        return
    if not apply:
        print("dry-run：加 --apply 才落盘")
        return

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = ROOT / "tmp" / f"backup-inq-strings-{ts}"
    bak.mkdir(parents=True, exist_ok=True)
    for path, new_src in touched.items():
        shutil.copy2(path, bak / path.name)
        # 走 bytes 写回：write_text 在 Windows 上会把 \n 翻成 \r\n，
        # 而全库 UCL 都是 LF-only（validate_ucl.py 强制）。
        path.write_bytes(new_src.encode("utf-8"))
        print(f"  wrote {path.relative_to(ROOT)} (backup: {bak.name}/{path.name})")


if __name__ == "__main__":
    main()
